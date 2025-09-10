const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const { pool } = require('../config/database');
const router = express.Router();

// Get user profile
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const userQuery = `
      SELECT 
        id, email, phone, first_name, last_name, 
        profile_photo, home_address, work_address, gender, 
        safety_preferences, theme_preference,
        is_verified, is_active, created_at, updated_at
      FROM users 
      WHERE id = $1
    `;
    
    const result = await pool.query(userQuery, [userId]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const user = result.rows[0];
    
    // Get user statistics
    const statsQuery = `
      SELECT 
        COUNT(*) as total_trips,
        COALESCE(AVG(rating), 0) as average_rating,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_trips
      FROM rides 
      WHERE customer_id = $1
    `;
    
    const statsResult = await pool.query(statsQuery, [userId]);
    const stats = statsResult.rows[0] || { total_trips: 0, average_rating: 0, completed_trips: 0 };
    
    res.json({
      message: 'User profile retrieved successfully',
      user: {
        ...user,
        stats: {
          totalTrips: parseInt(stats.total_trips) || 0,
          averageRating: parseFloat(stats.average_rating) || 0,
          completedTrips: parseInt(stats.completed_trips) || 0,
        }
      }
    });
    
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Update user profile
router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { 
      firstName, 
      lastName, 
      profilePhoto, 
      homeAddress, 
      workAddress,
      gender,
      safetyPreferences,
      themePreference
    } = req.body;
    
    const updateQuery = `
      UPDATE users 
      SET 
        first_name = COALESCE($1, first_name),
        last_name = COALESCE($2, last_name),
        profile_photo = COALESCE($3, profile_photo),
        home_address = COALESCE($4, home_address),
        work_address = COALESCE($5, work_address),
        gender = COALESCE($6, gender),
        safety_preferences = COALESCE($7, safety_preferences),
        theme_preference = COALESCE($8, theme_preference),
        updated_at = NOW()
      WHERE id = $9
      RETURNING id, email, phone, first_name, last_name, 
               profile_photo, home_address, work_address, gender,
               safety_preferences, theme_preference,
               is_verified, is_active, created_at, updated_at
    `;
    
    const result = await pool.query(updateQuery, [
      firstName, 
      lastName, 
      profilePhoto, 
      homeAddress, 
      workAddress,
      gender,
      safetyPreferences ? JSON.stringify(safetyPreferences) : null,
      themePreference,
      userId
    ]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.json({
      message: 'User profile updated successfully',
      user: result.rows[0]
    });
    
  } catch (error) {
    console.error('Error updating user profile:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Add saved address
router.post('/addresses', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { type, address, latitude, longitude, label } = req.body;
    
    const insertQuery = `
      INSERT INTO user_addresses (user_id, type, address, latitude, longitude, label)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `;
    
    const result = await pool.query(insertQuery, [
      userId, type, address, latitude, longitude, label
    ]);
    
    res.json({
      message: 'Address saved successfully',
      address: result.rows[0]
    });
    
  } catch (error) {
    console.error('Error saving address:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Get user saved addresses
router.get('/addresses', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const query = `
      SELECT * FROM user_addresses 
      WHERE user_id = $1 
      ORDER BY created_at DESC
    `;
    
    const result = await pool.query(query, [userId]);
    
    res.json({
      message: 'Addresses retrieved successfully',
      addresses: result.rows
    });
    
  } catch (error) {
    console.error('Error fetching addresses:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

module.exports = router;
