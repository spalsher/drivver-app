const express = require('express');
const { body, validationResult } = require('express-validator');
const db = require('../config/database');
const { authenticateToken } = require('../middleware/auth');
const { calculateDistance, isPointInCircle } = require('geolib');
const router = express.Router();

// Create new ride request
router.post('/request', authenticateToken, [
  body('pickup_location').isObject(),
  body('pickup_address').isLength({ min: 5 }).trim(),
  body('destination_location').isObject(),
  body('destination_address').isLength({ min: 5 }).trim(),
  body('customer_fare_offer').isFloat({ min: 1 }),
  body('passenger_count').optional().isInt({ min: 1, max: 6 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const {
      pickup_location,
      pickup_address,
      destination_location,
      destination_address,
      customer_fare_offer,
      passenger_count = 1,
      special_instructions,
      ride_type = 'standard'
    } = req.body;

    // Calculate estimated distance and duration
    const distance = calculateDistance(
      { latitude: pickup_location.lat, longitude: pickup_location.lng },
      { latitude: destination_location.lat, longitude: destination_location.lng }
    );
    const estimated_distance_km = distance / 1000; // Convert to km
    const estimated_duration_minutes = Math.round(estimated_distance_km * 2.5); // Rough estimate

    // Set expiration time (15 minutes from now)
    const expires_at = new Date(Date.now() + 15 * 60 * 1000);

    const result = await db.query(
      `INSERT INTO ride_requests (
        customer_id, pickup_location, pickup_address, destination_location, 
        destination_address, customer_fare_offer, estimated_distance_km, 
        estimated_duration_minutes, passenger_count, special_instructions, 
        ride_type, expires_at
      ) VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $4, ST_SetSRID(ST_MakePoint($5, $6), 4326), $7, $8, $9, $10, $11, $12, $13, $14)
      RETURNING id, created_at`,
      [
        req.user.userId,
        pickup_location.lng, pickup_location.lat,
        pickup_address,
        destination_location.lng, destination_location.lat,
        destination_address,
        customer_fare_offer,
        estimated_distance_km,
        estimated_duration_minutes,
        passenger_count,
        special_instructions,
        ride_type,
        expires_at
      ]
    );

    const rideRequest = result.rows[0];

    // Find nearby drivers (within 10km)
    const nearbyDrivers = await db.query(
      `SELECT d.id, d.user_id, u.first_name, u.last_name, d.vehicle_make, d.vehicle_model, 
              d.rating, ST_Distance(d.current_location, ST_SetSRID(ST_MakePoint($1, $2), 4326)) as distance
       FROM drivers d 
       JOIN users u ON d.user_id = u.id
       WHERE d.is_online = true 
         AND d.is_approved = true 
         AND ST_DWithin(d.current_location, ST_SetSRID(ST_MakePoint($1, $2), 4326), 10000)
       ORDER BY distance ASC
       LIMIT 20`,
      [pickup_location.lng, pickup_location.lat]
    );

    // Emit to nearby drivers via Socket.io
    req.app.get('io').emit('new-ride-request', {
      rideRequestId: rideRequest.id,
      customerFareOffer: customer_fare_offer,
      pickupLocation: pickup_location,
      pickupAddress: pickup_address,
      destinationLocation: destination_location,
      destinationAddress: destination_address,
      estimatedDistance: estimated_distance_km,
      estimatedDuration: estimated_duration_minutes,
      passengerCount: passenger_count,
      rideType: ride_type,
      nearbyDriverIds: nearbyDrivers.rows.map(d => d.user_id)
    });

    res.status(201).json({
      message: 'Ride request created successfully',
      rideRequest: {
        id: rideRequest.id,
        customer_fare_offer,
        pickup_address,
        destination_address,
        estimated_distance_km,
        estimated_duration_minutes,
        passenger_count,
        ride_type,
        status: 'pending',
        expires_at,
        created_at: rideRequest.created_at,
        nearby_drivers_count: nearbyDrivers.rows.length
      }
    });

  } catch (error) {
    console.error('Create ride request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get ride request status
router.get('/request/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      `SELECT rr.*, u.first_name as customer_first_name, u.last_name as customer_last_name,
              ST_X(rr.pickup_location) as pickup_lng, ST_Y(rr.pickup_location) as pickup_lat,
              ST_X(rr.destination_location) as dest_lng, ST_Y(rr.destination_location) as dest_lat,
              d.user_id as driver_user_id, du.first_name as driver_first_name, 
              du.last_name as driver_last_name, d.vehicle_make, d.vehicle_model, d.rating
       FROM ride_requests rr
       JOIN users u ON rr.customer_id = u.id
       LEFT JOIN drivers d ON rr.accepted_driver_id = d.id
       LEFT JOIN users du ON d.user_id = du.id
       WHERE rr.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ride request not found' });
    }

    const rideRequest = result.rows[0];

    // Check if user is authorized to view this request
    if (rideRequest.customer_id !== req.user.userId && rideRequest.driver_user_id !== req.user.userId) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    // Get haggling offers for this ride
    const offersResult = await db.query(
      `SELECT ho.*, d.user_id as driver_user_id, u.first_name as driver_first_name, 
              u.last_name as driver_last_name, d.vehicle_make, d.vehicle_model, d.rating
       FROM haggling_offers ho
       JOIN drivers d ON ho.driver_id = d.id
       JOIN users u ON d.user_id = u.id
       WHERE ho.ride_request_id = $1
       ORDER BY ho.created_at ASC`,
      [id]
    );

    res.json({
      rideRequest: {
        id: rideRequest.id,
        customer_id: rideRequest.customer_id,
        customer_name: `${rideRequest.customer_first_name} ${rideRequest.customer_last_name}`,
        pickup_location: { lat: rideRequest.pickup_lat, lng: rideRequest.pickup_lng },
        pickup_address: rideRequest.pickup_address,
        destination_location: { lat: rideRequest.dest_lat, lng: rideRequest.dest_lng },
        destination_address: rideRequest.destination_address,
        customer_fare_offer: parseFloat(rideRequest.customer_fare_offer),
        final_agreed_fare: rideRequest.final_agreed_fare ? parseFloat(rideRequest.final_agreed_fare) : null,
        estimated_distance_km: parseFloat(rideRequest.estimated_distance_km),
        estimated_duration_minutes: rideRequest.estimated_duration_minutes,
        passenger_count: rideRequest.passenger_count,
        ride_type: rideRequest.ride_type,
        special_instructions: rideRequest.special_instructions,
        status: rideRequest.status,
        expires_at: rideRequest.expires_at,
        created_at: rideRequest.created_at,
        driver: rideRequest.driver_user_id ? {
          id: rideRequest.driver_user_id,
          name: `${rideRequest.driver_first_name} ${rideRequest.driver_last_name}`,
          vehicle: `${rideRequest.vehicle_make} ${rideRequest.vehicle_model}`,
          rating: parseFloat(rideRequest.rating)
        } : null
      },
      haggling_offers: offersResult.rows.map(offer => ({
        id: offer.id,
        driver_id: offer.driver_user_id,
        driver_name: `${offer.driver_first_name} ${offer.driver_last_name}`,
        vehicle: `${offer.vehicle_make} ${offer.vehicle_model}`,
        rating: parseFloat(offer.rating),
        driver_fare_offer: parseFloat(offer.driver_fare_offer),
        customer_counter_offer: offer.customer_counter_offer ? parseFloat(offer.customer_counter_offer) : null,
        driver_counter_offer: offer.driver_counter_offer ? parseFloat(offer.driver_counter_offer) : null,
        offer_round: offer.offer_round,
        status: offer.status,
        expires_at: offer.expires_at,
        created_at: offer.created_at
      }))
    });

  } catch (error) {
    console.error('Get ride request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Cancel ride request
router.post('/request/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      'UPDATE ride_requests SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND customer_id = $3 AND status IN ($4, $5) RETURNING id',
      ['cancelled', id, req.user.userId, 'pending', 'haggling']
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ride request not found or cannot be cancelled' });
    }

    // Emit cancellation to all involved parties
    req.app.get('io').emit('ride-request-cancelled', { rideRequestId: id });

    res.json({ message: 'Ride request cancelled successfully' });

  } catch (error) {
    console.error('Cancel ride request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user's ride history
router.get('/history', authenticateToken, async (req, res) => {
  try {
    const { page = 1, limit = 20, status } = req.query;
    const offset = (page - 1) * limit;

    let statusFilter = '';
    let queryParams = [req.user.userId, limit, offset];
    
    if (status) {
      statusFilter = 'AND t.status = $4';
      queryParams.push(status);
    }

    const result = await db.query(
      `SELECT t.*, rr.pickup_address, rr.destination_address,
              u.first_name as customer_first_name, u.last_name as customer_last_name,
              du.first_name as driver_first_name, du.last_name as driver_last_name,
              d.vehicle_make, d.vehicle_model
       FROM trips t
       JOIN ride_requests rr ON t.ride_request_id = rr.id
       JOIN users u ON t.customer_id = u.id
       LEFT JOIN drivers d ON t.driver_id = d.id
       LEFT JOIN users du ON d.user_id = du.id
       WHERE t.customer_id = $1 OR d.user_id = $1
       ${statusFilter}
       ORDER BY t.created_at DESC
       LIMIT $2 OFFSET $3`,
      queryParams
    );

    const trips = result.rows.map(trip => ({
      id: trip.id,
      pickup_address: trip.pickup_address,
      destination_address: trip.destination_address,
      final_fare: parseFloat(trip.final_fare),
      actual_distance_km: trip.actual_distance_km ? parseFloat(trip.actual_distance_km) : null,
      actual_duration_minutes: trip.actual_duration_minutes,
      status: trip.status,
      customer_rating: trip.customer_rating,
      driver_rating: trip.driver_rating,
      payment_status: trip.payment_status,
      payment_method: trip.payment_method,
      created_at: trip.created_at,
      start_time: trip.start_time,
      end_time: trip.end_time,
      customer: {
        name: `${trip.customer_first_name} ${trip.customer_last_name}`
      },
      driver: trip.driver_first_name ? {
        name: `${trip.driver_first_name} ${trip.driver_last_name}`,
        vehicle: `${trip.vehicle_make} ${trip.vehicle_model}`
      } : null
    }));

    res.json({
      trips,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: trips.length
      }
    });

  } catch (error) {
    console.error('Get ride history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
