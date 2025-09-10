const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const db = require('../config/database');
const router = express.Router();

// In-memory OTP storage (use Redis in production)
const otpStore = new Map();

// Register new user
router.post('/register', [
  body('email').isEmail().normalizeEmail(),
  body('phone').isMobilePhone(),
  body('password').isLength({ min: 6 }),
  body('first_name').isLength({ min: 2 }).trim(),
  body('last_name').isLength({ min: 2 }).trim(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, phone, password, first_name, last_name } = req.body;

    // Check if user already exists
    const existingUser = await db.query(
      'SELECT id FROM users WHERE email = $1 OR phone = $2',
      [email, phone]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: 'User already exists with this email or phone' });
    }

    // Hash password
    const saltRounds = 12;
    const password_hash = await bcrypt.hash(password, saltRounds);

    // Create user
    const result = await db.query(
      `INSERT INTO users (email, phone, password_hash, first_name, last_name) 
       VALUES ($1, $2, $3, $4, $5) RETURNING id, email, phone, first_name, last_name, created_at`,
      [email, phone, password_hash, first_name, last_name]
    );

    const user = result.rows[0];

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.status(201).json({
      message: 'User registered successfully',
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        first_name: user.first_name,
        last_name: user.last_name,
      },
      token
    });

  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Login user
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').exists(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;

    // Find user
    const result = await db.query(
      'SELECT id, email, phone, password_hash, first_name, last_name, is_verified, is_active FROM users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(401).json({ error: 'Account is deactivated' });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Update last login
    await db.query(
      'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
      [user.id]
    );

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    // Check if user is also a driver
    const driverResult = await db.query(
      'SELECT id, is_approved, is_online FROM drivers WHERE user_id = $1',
      [user.id]
    );

    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        first_name: user.first_name,
        last_name: user.last_name,
        is_verified: user.is_verified,
        is_driver: driverResult.rows.length > 0,
        driver_approved: driverResult.rows.length > 0 ? driverResult.rows[0].is_approved : false,
      },
      token
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Verify token
router.get('/verify', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const result = await db.query(
      'SELECT id, email, phone, first_name, last_name, is_verified, is_active FROM users WHERE id = $1',
      [decoded.userId]
    );

    if (result.rows.length === 0 || !result.rows[0].is_active) {
      return res.status(401).json({ error: 'User not found or inactive' });
    }

    const user = result.rows[0];

    // Check if user is also a driver
    const driverResult = await db.query(
      'SELECT id, is_approved, is_online FROM drivers WHERE user_id = $1',
      [user.id]
    );

    res.json({
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        first_name: user.first_name,
        last_name: user.last_name,
        is_verified: user.is_verified,
        is_driver: driverResult.rows.length > 0,
        driver_approved: driverResult.rows.length > 0 ? driverResult.rows[0].is_approved : false,
      }
    });

  } catch (error) {
    console.error('Token verification error:', error);
    res.status(401).json({ error: 'Invalid token' });
  }
});

// Send OTP to phone number
router.post('/send-otp', [
  body('phone').isMobilePhone(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { phone } = req.body;

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Store OTP with expiration (5 minutes)
    const otpData = {
      otp,
      phone,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 minutes
    };
    
    otpStore.set(phone, otpData);

    // TODO: Integrate with SMS service (Twilio, AWS SNS, etc.)
    console.log(`OTP for ${phone}: ${otp}`); // For development only
    
    res.json({
      message: 'OTP sent successfully',
      // Don't send OTP in response in production
      ...(process.env.NODE_ENV === 'development' && { otp })
    });

  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({ error: 'Failed to send OTP' });
  }
});

// Verify OTP and create/login user
router.post('/verify-otp', [
  body('phone').isMobilePhone(),
  body('otp').isLength({ min: 6, max: 6 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { phone, otp } = req.body;

    // Check if OTP exists and is valid
    const otpData = otpStore.get(phone);
    
    if (!otpData) {
      return res.status(400).json({ error: 'OTP not found or expired' });
    }

    if (new Date() > otpData.expiresAt) {
      otpStore.delete(phone);
      return res.status(400).json({ error: 'OTP has expired' });
    }

    if (otpData.otp !== otp) {
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    // OTP is valid, remove it from store
    otpStore.delete(phone);

    // Check if user exists
    let result = await db.query(
      'SELECT id, email, phone, first_name, last_name, is_verified, is_active, created_at, updated_at FROM users WHERE phone = $1',
      [phone]
    );

    let user;
    
    if (result.rows.length === 0) {
      // Create new user with phone number
      const insertResult = await db.query(
        `INSERT INTO users (phone, first_name, last_name, email, password_hash, is_verified) 
         VALUES ($1, $2, $3, $4, $5, $6) 
         RETURNING id, email, phone, first_name, last_name, is_verified, is_active, created_at, updated_at`,
        [
          phone, 
          'User', // Default first name
          phone.slice(-4), // Use last 4 digits as last name
          `${phone}@drivrr.app`, // Generate email
          '', // No password for OTP users
          true // Mark as verified since they verified phone
        ]
      );
      user = insertResult.rows[0];
    } else {
      user = result.rows[0];
      
      if (!user.is_active) {
        return res.status(401).json({ error: 'Account is deactivated' });
      }

      // Update last login
      await db.query(
        'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
        [user.id]
      );
    }

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, phone: user.phone },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      message: 'OTP verified successfully',
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        first_name: user.first_name,
        last_name: user.last_name,
        is_verified: user.is_verified,
        is_active: user.is_active,
        created_at: user.created_at,
        updated_at: user.updated_at,
      },
      token
    });

  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({ error: 'Failed to verify OTP' });
  }
});

module.exports = router;
