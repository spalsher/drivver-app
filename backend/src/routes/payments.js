const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const router = express.Router();

// Process payment
router.post('/process', authenticateToken, async (req, res) => {
  res.json({ message: 'Process payment endpoint - to be implemented' });
});

// Get payment methods
router.get('/methods', authenticateToken, async (req, res) => {
  res.json({ message: 'Get payment methods endpoint - to be implemented' });
});

module.exports = router;
