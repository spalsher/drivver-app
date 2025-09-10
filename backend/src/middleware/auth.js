const jwt = require('jsonwebtoken');
const db = require('../config/database');

const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({ error: 'Access token required' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Verify user still exists and is active
    const result = await db.query(
      'SELECT id, email, is_active FROM users WHERE id = $1',
      [decoded.userId]
    );

    if (result.rows.length === 0 || !result.rows[0].is_active) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    req.user = {
      userId: decoded.userId,
      email: decoded.email
    };

    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid token' });
    } else if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }
    
    console.error('Authentication middleware error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

const authenticateDriver = async (req, res, next) => {
  try {
    // First authenticate the token
    await authenticateToken(req, res, () => {});
    
    if (res.headersSent) return;

    // Check if user is an approved driver
    const result = await db.query(
      'SELECT id, is_approved FROM drivers WHERE user_id = $1',
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(403).json({ error: 'Driver account required' });
    }

    if (!result.rows[0].is_approved) {
      return res.status(403).json({ error: 'Driver account not approved' });
    }

    req.driver = {
      id: result.rows[0].id,
      ...req.user
    };

    next();
  } catch (error) {
    console.error('Driver authentication middleware error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = {
  authenticateToken,
  authenticateDriver
};
