const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs');
const { createServer } = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app = express();
const server = createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.NODE_ENV === 'production' 
      ? ["https://your-customer-app.com", "https://your-driver-app.com"]
      : true, // Allow all origins in development
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"], // Allow inline scripts for admin panel
      scriptSrcAttr: ["'unsafe-inline'"], // Allow inline event handlers (onclick, etc.)
      styleSrc: ["'self'", "'unsafe-inline'", "https:"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "http://192.168.20.67:3000"], // Allow fetch requests to same origin and network IP
      fontSrc: ["'self'", "https:", "data:"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
      upgradeInsecureRequests: null, // Disable automatic HTTPS upgrade
    },
  },
}));
app.use(compression());
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? ["https://your-customer-app.com", "https://your-driver-app.com"]
    : ["http://localhost:3000", "http://192.168.20.67:3000", "http://127.0.0.1:3000"], // Allow network IP in development
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve static files (for admin panel and uploaded documents)
app.use(express.static(path.join(__dirname, '../public')));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Specific route for document images with proper headers
app.get('/uploads/documents/:filename', (req, res) => {
  const filename = req.params.filename;
  const filePath = path.join(__dirname, '../uploads/documents', filename);
  
  // Check if file exists
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found' });
  }
  
  // Set proper headers for images
  res.setHeader('Content-Type', 'image/jpeg');
  res.setHeader('Cache-Control', 'public, max-age=31536000');
  res.sendFile(filePath);
});

// Socket.io middleware and connection handling
io.use((socket, next) => {
  // Add authentication middleware for socket connections
  const token = socket.handshake.auth.token;
  if (token) {
    // Verify JWT token here
    console.log('🔐 WebSocket authenticated with token');
    next();
  } else {
    // Allow unauthenticated connections for development
    console.log('⚠️ WebSocket connection without token - allowing for development');
    next();
  }
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // Join user room for personalized updates
  socket.on('join_user_room', (data) => {
    const { userId } = data;
    socket.join(`user-${userId}`);
    console.log(`User ${userId} joined room`);
  });

  // Join driver room for ride requests
  socket.on('join_driver_room', (data) => {
    const { driverId, userType } = data;
    socket.join(`driver-${driverId}`);
    socket.join('online-drivers'); // Group for broadcasting ride requests
    
    // Get current count of online drivers
    const onlineDriversRoom = io.sockets.adapter.rooms.get('online-drivers');
    const driverCount = onlineDriversRoom ? onlineDriversRoom.size : 0;
    
    console.log(`🚗 Driver ${driverId} joined driver room and online drivers pool`);
    console.log(`📊 Total online drivers: ${driverCount}`);
  });

  // Handle ride request creation
  socket.on('create_ride_request', (data) => {
    console.log('🚗 New ride request received from customer:', data);
    
    // Generate unique ride ID
    const rideId = `ride_${Date.now()}`;
    const rideRequest = {
      rideId,
      ...data,
      timestamp: new Date().toISOString(),
    };
    
    // Get count of drivers in online-drivers room
    const onlineDriversRoom = io.sockets.adapter.rooms.get('online-drivers');
    const driverCount = onlineDriversRoom ? onlineDriversRoom.size : 0;
    
    console.log(`📡 Broadcasting ride request ${rideId} to ${driverCount} online drivers`);
    console.log(`🚗 Ride details: ${data.pickup} → ${data.destination}, Fare: PKR ${data.customerFareOffer}`);
    
    // Broadcast to ALL online drivers
    io.to('online-drivers').emit('new_ride_request', rideRequest);
    
    // Also log the actual broadcast
    console.log(`✅ Ride request ${rideId} broadcasted successfully`);
  });

  // Handle driver status updates
  socket.on('driver_status_update', (data) => {
    const { driverId, isOnline } = data;
    console.log(`🚗 Driver ${driverId} is now ${isOnline ? 'ONLINE' : 'OFFLINE'}`);
    
    if (isOnline) {
      socket.join('online-drivers');
    } else {
      socket.leave('online-drivers');
    }
  });

  // Handle driver offers
  socket.on('driver_offer', (data) => {
    const { rideId, customerId, driverId, offer } = data;
    console.log(`💰 Driver ${driverId} offered PKR ${offer} for ride ${rideId}`);
    
    // Send offer to customer
    io.to(`user-${customerId}`).emit('driver_offer', {
      rideId,
      driverId,
      offer,
      timestamp: new Date().toISOString(),
    });
  });

  // Handle counter offers
  socket.on('counter_offer', (data) => {
    const { rideId, driverId, customerId, newPrice } = data;
    console.log(`🔄 Customer ${customerId} counter-offered PKR ${newPrice}`);
    
    // Send counter-offer to driver
    io.to(`user-${driverId}`).emit('counter_offer_response', {
      rideId,
      customerId,
      newPrice,
      timestamp: new Date().toISOString(),
    });
  });

  // Handle offer acceptance
  socket.on('accept_offer', (data) => {
    const { rideId, driverId, customerId, finalPrice } = data;
    console.log(`✅ Offer accepted! Ride ${rideId} for PKR ${finalPrice}`);
    
    // Notify both parties
    io.to(`user-${driverId}`).emit('offer_accepted', {
      rideId,
      finalPrice,
      status: 'accepted',
    });
    
    io.to(`user-${customerId}`).emit('ride_confirmed', {
      rideId,
      driverId,
      finalPrice,
      status: 'confirmed',
    });
  });

  // Handle location updates
  socket.on('update_location', (data) => {
    const { userId, latitude, longitude } = data;
    
    // Broadcast location updates during active trips
    socket.broadcast.emit('location_update', {
      userId,
      latitude,
      longitude,
      timestamp: new Date().toISOString(),
    });
  });

  // Handle ride cancellation
  socket.on('cancel_ride', (data) => {
    const { rideId, userId } = data;
    console.log(`❌ Ride ${rideId} cancelled by ${userId}`);
    
    // Notify all involved parties
    socket.broadcast.emit('ride_cancelled', {
      rideId,
      cancelledBy: userId,
      timestamp: new Date().toISOString(),
    });
  });

  // ==================== TRIP TRACKING HANDLERS ====================
  
  // Handle driver location updates during trip
  socket.on('driver_location_update', (data) => {
    const { rideId, driverId, latitude, longitude, eta } = data;
    console.log(`📍 Driver ${driverId} location update for ride ${rideId}: ${latitude}, ${longitude}`);
    
    // Send location to customer
    io.to(`user-${data.customerId}`).emit('driver_location_update', {
      rideId,
      driverId,
      latitude,
      longitude,
      eta,
      timestamp: new Date().toISOString(),
    });
  });
  
  // Handle trip status updates
  socket.on('update_trip_status', (data) => {
    const { rideId, status, driverId, customerId } = data;
    console.log(`🚦 Trip ${rideId} status updated to: ${status}`);
    
    // Calculate progress percentage
    let progress = 0;
    switch (status) {
      case 'accepted': progress = 10; break;
      case 'pickup': progress = 25; break;
      case 'in_transit': progress = 50; break;
      case 'arrived': progress = 75; break;
      case 'completed': progress = 100; break;
    }
    
    // Notify both customer and driver
    const statusUpdate = {
      rideId,
      status,
      progress,
      timestamp: new Date().toISOString(),
    };
    
    if (customerId) io.to(`user-${customerId}`).emit('trip_status_update', statusUpdate);
    if (driverId) io.to(`user-${driverId}`).emit('trip_status_update', statusUpdate);
  });
  
  // Handle request for driver location
  socket.on('request_driver_location', (data) => {
    const { rideId, userId } = data;
    console.log(`📍 Location requested for ride ${rideId} by user ${userId}`);
    
    // Simulate driver location (in production, get from database)
    const driverLocation = {
      rideId,
      latitude: 24.8271 + (Math.random() - 0.5) * 0.01,
      longitude: 67.0243 + (Math.random() - 0.5) * 0.01,
      eta: '5 mins',
      timestamp: new Date().toISOString(),
    };
    
    socket.emit('driver_location_update', driverLocation);
  });
  
  // Handle trip tracking start
  socket.on('start_trip_tracking', (data) => {
    const { rideId, userId } = data;
    console.log(`🚗 Starting trip tracking for ride ${rideId}`);
    
    // Join trip-specific room for real-time updates
    socket.join(`trip-${rideId}`);
    
    // Send initial trip status
    io.to(`trip-${rideId}`).emit('trip_status_update', {
      rideId,
      status: 'accepted',
      progress: 10,
      timestamp: new Date().toISOString(),
    });
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/rides', require('./routes/rides'));
app.use('/api/drivers', require('./routes/drivers'));
app.use('/api/payments', require('./routes/payments'));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Drivrr API is running',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Something went wrong!', 
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Drivrr API server running on port ${PORT}`);
  console.log(`Server accessible at: http://192.168.20.67:${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`Socket.io server ready for connections`);
});

module.exports = { app, server, io };
