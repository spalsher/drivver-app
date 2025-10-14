const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticateToken } = require('../middleware/auth');
const { pool } = require('../config/database');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads/documents');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, `${req.user.userId}-${req.body.documentType}-${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, and WebP images are allowed'), false);
    }
  }
});

// Get driver documents status
router.get('/documents', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // First get the driver ID from the user ID
    const driverQuery = `SELECT id FROM drivers WHERE user_id = $1`;
    const driverResult = await pool.query(driverQuery, [userId]);
    
    if (driverResult.rows.length === 0) {
      // No driver record yet - return empty documents list
      return res.json({ 
        success: true, 
        documents: [] 
      });
    }
    
    const driverId = driverResult.rows[0].id;
    
    const query = `
      SELECT 
        document_type as type,
        status,
        COALESCE(file_path, document_url) as file_path,
        rejection_reason,
        uploaded_at,
        reviewed_at
      FROM driver_documents 
      WHERE driver_id = $1 
      ORDER BY updated_at DESC
    `;
    
    const result = await pool.query(query, [driverId]);
    
    res.json({
      success: true,
      documents: result.rows.map(doc => ({
        type: doc.type,
        status: doc.status,
        filePath: doc.file_path,
        rejectionReason: doc.rejection_reason,
        uploadedAt: doc.uploaded_at,
        reviewedAt: doc.reviewed_at,
      }))
    });
  } catch (error) {
    console.error('❌ Get documents error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch documents' 
    });
  }
});

// Upload document
router.post('/documents/upload', authenticateToken, upload.single('file'), async (req, res) => {
  try {
    const { documentType, extractedData, geniusScanConfidence, scanMethod, fileType } = req.body;
    const userId = req.user.userId;
    
    // Handle PDF extracted data uploads (no file, just data)
    const isPdfExtractedData = fileType === 'pdf_extracted_data';
    
    if (!req.file && !isPdfExtractedData) {
      return res.status(400).json({ 
        success: false, 
        error: 'No file uploaded' 
      });
    }

    // Parse extracted data if it's a string
    let parsedExtractedData = null;
    if (extractedData) {
      try {
        parsedExtractedData = typeof extractedData === 'string' ? JSON.parse(extractedData) : extractedData;
        console.log('📋 Received extracted data:', parsedExtractedData);
        console.log('🎯 Genius Scan confidence:', geniusScanConfidence);
        console.log('🔧 Scan method:', scanMethod);
      } catch (e) {
        console.warn('⚠️ Failed to parse extracted data:', e.message);
      }
    }
    
    // First get the driver ID from the user ID, or create driver record if it doesn't exist
    let driverQuery = `SELECT id FROM drivers WHERE user_id = $1`;
    let driverResult = await pool.query(driverQuery, [userId]);
    let driverId;
    
    if (driverResult.rows.length === 0) {
      console.log(`📝 Creating new driver record for user ${userId}`);
      
      // Create a new driver record with default values
      const createDriverQuery = `
        INSERT INTO drivers (
          user_id, 
          license_number, 
          license_expiry, 
          vehicle_make, 
          vehicle_model, 
          vehicle_year, 
          vehicle_color, 
          plate_number,
          is_approved,
          documents_verified
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) 
        RETURNING id
      `;
      
      // Use temporary/placeholder values that will be updated when documents are processed
      const tempValues = [
        userId,
        'PENDING', // Will be extracted from license via ML Kit
        '2099-12-31', // Temporary far future date
        'PENDING', // Will be extracted from registration
        'PENDING', // Will be extracted from registration  
        2024, // Default year
        'PENDING', // Will be extracted from registration
        'PENDING', // Will be extracted from registration
        false, // Not approved until documents are verified
        false // Documents not verified yet
      ];
      
      const createResult = await pool.query(createDriverQuery, tempValues);
      driverId = createResult.rows[0].id;
      console.log(`✅ Created new driver record: ${driverId} for user ${userId}`);
    } else {
      driverId = driverResult.rows[0].id;
    }

    if (!documentType) {
      return res.status(400).json({ 
        success: false, 
        error: 'Document type is required' 
      });
    }

    // Valid document types (updated to support front/back)
    const validTypes = [
      'drivingLicense',
      'drivingLicenseFront',
      'drivingLicenseBack',
      'vehicleRegistration', 
      'insuranceCertificate',
      'driverPhoto',
      'vehiclePhoto'
    ];

    if (!validTypes.includes(documentType)) {
      return res.status(400).json({ 
        success: false, 
        error: 'Invalid document type' 
      });
    }

    let filePath = null;
    let fileDataBase64 = null;

    // Handle file uploads (normal case)
    if (req.file) {
      filePath = `/uploads/documents/${req.file.filename}`;
      
      // Convert uploaded file to Base64 for database storage
      try {
        const fileBuffer = fs.readFileSync(req.file.path);
        const mimeType = req.file.mimetype || 'image/jpeg';
        fileDataBase64 = `data:${mimeType};base64,${fileBuffer.toString('base64')}`;
        console.log(`📦 Converted file to Base64 (${Math.round(fileDataBase64.length / 1024)}KB)`);
      } catch (err) {
        console.error('❌ Failed to convert file to Base64:', err);
      }
    } else if (isPdfExtractedData) {
      // Handle PDF extracted data (no actual file)
      filePath = 'pdf_extracted_data';
      fileDataBase64 = null;
      console.log('📄 Processing PDF extracted data upload (no file)');
    }

    // Check if document already exists
    const existingQuery = `
      SELECT id, file_path FROM driver_documents 
      WHERE driver_id = $1 AND document_type = $2
    `;
    const existingResult = await pool.query(existingQuery, [driverId, documentType]);

    if (existingResult.rows.length > 0) {
      // Delete old file if exists (but not for PDF extracted data)
      const oldDocument = existingResult.rows[0];
      if (oldDocument.file_path && oldDocument.file_path !== 'pdf_extracted_data') {
        const oldFilePath = path.join(__dirname, '..', oldDocument.file_path);
        if (fs.existsSync(oldFilePath)) {
          fs.unlinkSync(oldFilePath);
        }
      }

      // Update existing document
      const updateQuery = `
        UPDATE driver_documents 
        SET 
          file_path = $1,
          document_url = $1,
          file_data = $4,
          status = 'under_review',
          uploaded_at = NOW(),
          rejection_reason = NULL,
          reviewed_at = NULL,
          extracted_data = $5,
          ml_confidence = $6,
          updated_at = NOW()
        WHERE driver_id = $2 AND document_type = $3
      `;
      await pool.query(updateQuery, [
        filePath, 
        driverId, 
        documentType,
        fileDataBase64,
        parsedExtractedData ? JSON.stringify(parsedExtractedData) : null,
        geniusScanConfidence || null
      ]);
    } else {
      // Create new document
      const insertQuery = `
        INSERT INTO driver_documents (
          driver_id, document_type, file_path, document_url, file_data, status, extracted_data, ml_confidence, uploaded_at, created_at, updated_at
        ) VALUES ($1, $2, $3, $3, $4, 'under_review', $5, $6, NOW(), NOW(), NOW())
      `;
      await pool.query(insertQuery, [
        driverId, 
        documentType, 
        filePath,
        fileDataBase64,
        parsedExtractedData ? JSON.stringify(parsedExtractedData) : null,
        geniusScanConfidence || null
      ]);
    }

    // Update driver record with extracted data if it's a driving license
    if ((documentType === 'drivingLicense' || documentType === 'drivingLicenseFront') && 
        parsedExtractedData && parsedExtractedData.licenseNumber && 
        parsedExtractedData.licenseNumber !== 'Not detected') {
      
      try {
        // Check if another driver already has this license number
        const existingLicenseQuery = `SELECT id, user_id FROM drivers WHERE license_number = $1 AND user_id != $2`;
        const existingLicenseResult = await pool.query(existingLicenseQuery, [parsedExtractedData.licenseNumber, userId]);
        
        if (existingLicenseResult.rows.length > 0) {
          console.warn(`⚠️ License number ${parsedExtractedData.licenseNumber} already exists for another driver`);
          // Don't update the license number, but continue with document upload
        } else {
          // Update the driver's license number and expiry date
          const updateDriverQuery = `
            UPDATE drivers 
            SET license_number = $1, 
                license_expiry = COALESCE($2::date, license_expiry),
                updated_at = NOW()
            WHERE user_id = $3
          `;
          
          // Parse expiry date if available
          let expiryDate = null;
          if (parsedExtractedData.expiryDate && parsedExtractedData.expiryDate !== 'Not detected') {
            try {
              // Convert date format from DD-MMM-YYYY to YYYY-MM-DD
              const dateParts = parsedExtractedData.expiryDate.split('-');
              if (dateParts.length === 3) {
                const monthMap = {
                  'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
                  'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
                  'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
                };
                const month = monthMap[dateParts[1]] || '12';
                expiryDate = `${dateParts[2]}-${month}-${dateParts[0].padStart(2, '0')}`;
              }
            } catch (e) {
              console.warn('⚠️ Failed to parse expiry date:', parsedExtractedData.expiryDate);
            }
          }
          
          await pool.query(updateDriverQuery, [
            parsedExtractedData.licenseNumber,
            expiryDate,
            userId
          ]);
          
          console.log(`✅ Updated driver license: ${parsedExtractedData.licenseNumber} (expires: ${expiryDate || 'unknown'})`);
        }
      } catch (updateError) {
        console.error('❌ Failed to update driver license info:', updateError);
        // Continue with document upload even if driver update fails
      }
    }

    // Update driver verification status
    await updateDriverVerificationStatus(driverId);

    console.log(`✅ Document uploaded: ${documentType} for driver ${driverId} (method: ${scanMethod || 'unknown'})`);

    res.json({
      success: true,
      message: 'Document uploaded successfully',
      filePath: filePath,
      extractedData: parsedExtractedData,
      scanMethod: scanMethod,
    });

  } catch (error) {
    console.error('❌ Upload document error:', error);
    
    // Clean up uploaded file on error (but not for PDF extracted data)
    if (req.file) {
      const filePath = path.join(__dirname, '../uploads/documents', req.file.filename);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }

    res.status(500).json({ 
      success: false, 
      error: error.message || 'Failed to upload document' 
    });
  }
});

// Delete document
router.delete('/documents/:documentType', authenticateToken, async (req, res) => {
  try {
    const { documentType } = req.params;
    const userId = req.user.userId;
    
    // First get the driver ID from the user ID
    const driverQuery = `SELECT id FROM drivers WHERE user_id = $1`;
    const driverResult = await pool.query(driverQuery, [userId]);
    
    if (driverResult.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Driver profile not found' 
      });
    }
    
    const driverId = driverResult.rows[0].id;

    const selectQuery = `
      SELECT id, COALESCE(file_path, document_url) as file_path, status FROM driver_documents 
      WHERE driver_id = $1 AND document_type = $2
    `;
    const selectResult = await pool.query(selectQuery, [driverId, documentType]);

    if (selectResult.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Document not found' 
      });
    }

    const document = selectResult.rows[0];

    // Don't allow deletion of approved documents
    if (document.status === 'approved') {
      return res.status(400).json({ 
        success: false, 
        error: 'Cannot delete approved documents' 
      });
    }

    // Delete file from filesystem
    if (document.file_path) {
      const filePath = path.join(__dirname, '..', document.file_path);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }

    // Delete document from database
    const deleteQuery = `DELETE FROM driver_documents WHERE id = $1`;
    await pool.query(deleteQuery, [document.id]);

    // Update driver verification status
    await updateDriverVerificationStatus(driverId);

    console.log(`✅ Document deleted: ${documentType} for driver ${driverId}`);

    res.json({
      success: true,
      message: 'Document deleted successfully',
    });

  } catch (error) {
    console.error('❌ Delete document error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to delete document' 
    });
  }
});

// Get verification status
router.get('/verification-status', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // First get the driver ID from the user ID
    const driverQuery = `SELECT id FROM drivers WHERE user_id = $1`;
    const driverResult = await pool.query(driverQuery, [userId]);
    
    if (driverResult.rows.length === 0) {
      // No driver record yet - return default pending status
      return res.json({ 
        success: true,
        status: 'pending',
        isFullyVerified: false,
        approvedCount: 0,
        totalRequired: 6, // Updated to 6: front+back license + 4 other documents
        verificationLevel: 'pending',
        documents: {}
      });
    }
    
    const driverId = driverResult.rows[0].id;
    
    // Get user verification status
    const userQuery = `
      SELECT verification_status FROM users WHERE id = $1
    `;
    const userResult = await pool.query(userQuery, [userId]);
    
    // Get documents
    const documentsQuery = `
      SELECT 
        document_type,
        status,
        uploaded_at,
        reviewed_at,
        rejection_reason
      FROM driver_documents 
      WHERE driver_id = $1
    `;
    const documentsResult = await pool.query(documentsQuery, [driverId]);

    const requiredDocuments = [
      'drivingLicenseFront',
      'drivingLicenseBack',
      'vehicleRegistration', 
      'insuranceCertificate',
      'driverPhoto',
      'vehiclePhoto'
    ];

    const documentStatus = {};
    documentsResult.rows.forEach(doc => {
      documentStatus[doc.document_type] = {
        status: doc.status,
        uploadedAt: doc.uploaded_at,
        reviewedAt: doc.reviewed_at,
        rejectionReason: doc.rejection_reason,
      };
    });

    // Calculate verification level
    let verificationLevel = 'pending';
    const approvedCount = documentsResult.rows.filter(doc => doc.status === 'approved').length;
    const totalRequired = requiredDocuments.length;

    if (approvedCount === totalRequired) {
      verificationLevel = 'fully_verified';
    } else if (approvedCount > 0) {
      verificationLevel = 'partially_verified';
    } else if (documentsResult.rows.length > 0) {
      verificationLevel = 'documents_uploaded';
    }

    res.json({
      success: true,
      status: userResult.rows[0]?.verification_status || 'pending',
      verificationLevel,
      documents: documentStatus,
      approvedCount,
      totalRequired,
      isFullyVerified: approvedCount === totalRequired,
    });

  } catch (error) {
    console.error('❌ Get verification status error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch verification status' 
    });
  }
});

// Admin: Get all pending documents for review (Demo version - no auth required)
router.get('/admin/pending-documents', async (req, res) => {
  try {
    const query = `
      SELECT 
        dd.id,
        dd.document_type,
        dd.status,
        dd.uploaded_at,
        dd.file_path,
        dd.document_url,
        dd.file_data,
        dd.extracted_data,
        dd.ml_confidence,
        u.first_name,
        u.last_name,
        u.phone,
        u.email
      FROM driver_documents dd
      JOIN drivers d ON dd.driver_id = d.id
      JOIN users u ON d.user_id = u.id
      WHERE dd.status = 'under_review'
      ORDER BY dd.uploaded_at DESC
    `;
    
    const result = await pool.query(query);

    res.json({
      success: true,
      documents: result.rows,
    });

  } catch (error) {
    console.error('❌ Get pending documents error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch pending documents' 
    });
  }
});

// Admin: Approve or reject document (Demo version - no auth required)
router.post('/admin/review-document', async (req, res) => {
  try {
    const { documentId, action, rejectionReason } = req.body;

    if (!documentId || !action) {
      return res.status(400).json({ 
        success: false, 
        error: 'Document ID and action are required' 
      });
    }

    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ 
        success: false, 
        error: 'Action must be approve or reject' 
      });
    }

    const selectQuery = `
      SELECT driver_id FROM driver_documents WHERE id = $1
    `;
    const selectResult = await pool.query(selectQuery, [documentId]);
    
    if (selectResult.rows.length === 0) {
      return res.status(404).json({ 
        success: false, 
        error: 'Document not found' 
      });
    }

    const driverId = selectResult.rows[0].driver_id;

    // Update document status
    const updateQuery = `
      UPDATE driver_documents 
      SET 
        status = $1,
        reviewed_at = NOW(),
        reviewed_by = $2,
        rejection_reason = $3,
        updated_at = NOW()
      WHERE id = $4
    `;
    
    const status = action === 'approve' ? 'approved' : 'rejected';
    
    await pool.query(updateQuery, [
      status, 
      null, // No reviewer for demo
      action === 'reject' ? rejectionReason : null, 
      documentId
    ]);

    // Update driver verification status
    await updateDriverVerificationStatus(driverId);

    console.log(`✅ Document ${action}d: ${documentId} for driver ${driverId}`);

    res.json({
      success: true,
      message: `Document ${action}d successfully`,
    });

  } catch (error) {
    console.error('❌ Review document error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to review document' 
    });
  }
});

// Helper function to update driver verification status
async function updateDriverVerificationStatus(driverId) {
  try {
    // First get the user_id from the driver_id
    const driverQuery = `SELECT user_id FROM drivers WHERE id = $1`;
    const driverResult = await pool.query(driverQuery, [driverId]);
    
    if (driverResult.rows.length === 0) {
      console.error(`❌ Driver not found: ${driverId}`);
      return;
    }
    
    const userId = driverResult.rows[0].user_id;
    
    const documentsQuery = `
      SELECT status FROM driver_documents WHERE driver_id = $1
    `;
    const documentsResult = await pool.query(documentsQuery, [driverId]);
    
    const requiredDocuments = [
      'drivingLicense',
      'vehicleRegistration', 
      'insuranceCertificate',
      'driverPhoto',
      'vehiclePhoto'
    ];

    const approvedCount = documentsResult.rows.filter(doc => doc.status === 'approved').length;
    const rejectedCount = documentsResult.rows.filter(doc => doc.status === 'rejected').length;

    let verificationStatus = 'pending';
    
    if (approvedCount === requiredDocuments.length) {
      verificationStatus = 'verified';
    } else if (rejectedCount > 0) {
      verificationStatus = 'rejected';
    } else if (documentsResult.rows.length > 0) {
      verificationStatus = 'under_review';
    }

    const updateQuery = `
      UPDATE users 
      SET 
        verification_status = $1,
        updated_at = NOW()
      WHERE id = $2
    `;
    await pool.query(updateQuery, [verificationStatus, userId]); // Use userId instead of driverId

    console.log(`✅ Driver verification status updated: ${driverId} -> ${verificationStatus}`);
  } catch (error) {
    console.error('❌ Update verification status error:', error);
  }
}

// Admin: Test route
router.get('/admin/test', async (req, res) => {
  res.json({ success: true, message: 'Admin routes working' });
});

// Admin: Get all registered drivers (Demo version - no auth required)
router.get('/admin/drivers', async (req, res) => {
  try {
    // First, let's try a simpler query to see what columns exist
    const query = `
      SELECT 
        u.id as user_id,
        d.id as driver_id,
        u.first_name,
        u.last_name,
        u.phone,
        u.email,
        u.verification_status,
        u.created_at as registered_at,
        d.license_number,
        d.vehicle_make,
        d.vehicle_model,
        d.vehicle_year,
        d.vehicle_color,
        d.plate_number,
        d.vehicle_type
      FROM users u
      JOIN drivers d ON u.id = d.user_id
      ORDER BY u.created_at DESC
    `;
    const result = await pool.query(query);
    
    // Get document counts separately
    const docQuery = `
      SELECT 
        dd.driver_id,
        COUNT(*) as total_documents,
        COUNT(CASE WHEN dd.status = 'approved' THEN 1 END) as approved_documents,
        COUNT(CASE WHEN dd.status = 'under_review' THEN 1 END) as pending_documents,
        COUNT(CASE WHEN dd.status = 'rejected' THEN 1 END) as rejected_documents
      FROM driver_documents dd
      GROUP BY dd.driver_id
    `;
    const docResult = await pool.query(docQuery);
    
    // Create a map of document counts
    const docCounts = {};
    docResult.rows.forEach(row => {
      docCounts[row.driver_id] = {
        total: parseInt(row.total_documents) || 0,
        approved: parseInt(row.approved_documents) || 0,
        pending: parseInt(row.pending_documents) || 0,
        rejected: parseInt(row.rejected_documents) || 0,
      };
    });
    
    const drivers = result.rows.map(row => ({
      userId: row.user_id,
      driverId: row.driver_id,
      firstName: row.first_name,
      lastName: row.last_name,
      phone: row.phone,
      email: row.email,
      verificationStatus: row.verification_status,
      registeredAt: row.registered_at,
      licenseNumber: row.license_number,
      vehicle: {
        make: row.vehicle_make || 'Unknown',
        model: row.vehicle_model || '',
        year: row.vehicle_year || 0,
        color: row.vehicle_color || 'Unknown',
        plateNumber: row.plate_number || 'Unknown',
        type: row.vehicle_type || 'Unknown',
      },
      isActive: true, // Default to true since column doesn't exist
      stats: {
        totalTrips: 0, // Default values since columns don't exist
        rating: 5.0,
        totalEarnings: 0,
      },
      documents: docCounts[row.driver_id] || {
        total: 0,
        approved: 0,
        pending: 0,
        rejected: 0,
      }
    }));

    res.json({ success: true, drivers });
  } catch (error) {
    console.error('Error fetching drivers:', error.message);
    console.error('Error stack:', error.stack);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Admin: Update driver status (activate/deactivate)
router.post('/admin/drivers/:driverId/status', async (req, res) => {
  try {
    const { driverId } = req.params;
    const { isActive } = req.body;

    if (typeof isActive !== 'boolean') {
      return res.status(400).json({ success: false, error: 'isActive must be a boolean' });
    }

    const query = `UPDATE drivers SET is_active = $1, updated_at = NOW() WHERE id = $2`;
    await pool.query(query, [isActive, driverId]);

    console.log(`✅ Driver ${isActive ? 'activated' : 'deactivated'}: ${driverId}`);
    res.json({ success: true, message: `Driver ${isActive ? 'activated' : 'deactivated'} successfully` });
  } catch (error) {
    console.error('Error updating driver status:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Admin: Get documents for a specific driver
router.get('/admin/driver-documents/:driverId', async (req, res) => {
  try {
    const { driverId } = req.params;
    
    console.log('🔍 Loading documents for driver:', driverId);
    
    const query = `
      SELECT 
        id,
        driver_id,
        document_type,
        status,
        COALESCE(file_path, document_url) as file_path,
        file_data,
        extracted_data,
        ml_confidence,
        uploaded_at,
        reviewed_at,
        rejection_reason
      FROM driver_documents 
      WHERE driver_id = $1
      ORDER BY uploaded_at DESC
    `;
    
    const result = await pool.query(query, [driverId]);
    
    console.log(`✅ Found ${result.rows.length} documents for driver ${driverId}`);
    
    res.json({
      success: true,
      documents: result.rows
    });
  } catch (error) {
    console.error('❌ Error fetching driver documents:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch driver documents' 
    });
  }
});

module.exports = router;