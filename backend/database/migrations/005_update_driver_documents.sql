-- Migration: Update existing driver_documents table for new document verification system
-- Run this in your PostgreSQL database

-- First, let's add the missing columns and update the structure
ALTER TABLE driver_documents 
ADD COLUMN IF NOT EXISTS file_path VARCHAR(500),
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'under_review',
ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS reviewed_by INTEGER,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update the status column to match our new enum values
UPDATE driver_documents SET status = 
  CASE 
    WHEN verification_status = 'pending' THEN 'under_review'
    WHEN verification_status = 'approved' THEN 'approved'
    WHEN verification_status = 'rejected' THEN 'rejected'
    ELSE 'under_review'
  END;

-- Copy document_url to file_path if file_path is null
UPDATE driver_documents SET file_path = document_url WHERE file_path IS NULL;

-- Copy verified_at to reviewed_at
UPDATE driver_documents SET reviewed_at = verified_at WHERE reviewed_at IS NULL;

-- Update document types to match our new system
UPDATE driver_documents SET document_type = 
  CASE 
    WHEN document_type = 'license' THEN 'drivingLicense'
    WHEN document_type = 'vehicle_registration' THEN 'vehicleRegistration'
    WHEN document_type = 'insurance' THEN 'insuranceCertificate'
    WHEN document_type = 'identity' THEN 'driverPhoto'
    ELSE document_type
  END;

-- Add missing document type for vehicle photo if not exists
INSERT INTO driver_documents (driver_id, document_type, file_path, status, uploaded_at, created_at, updated_at)
SELECT 
  d.id as driver_id,
  'vehiclePhoto' as document_type,
  '/uploads/placeholder/vehicle-photo.jpg' as file_path,
  'not_uploaded' as status,
  NOW() as uploaded_at,
  NOW() as created_at,
  NOW() as updated_at
FROM drivers d
WHERE NOT EXISTS (
  SELECT 1 FROM driver_documents dd 
  WHERE dd.driver_id = d.id AND dd.document_type = 'vehiclePhoto'
);

-- Drop old constraints and add new ones
ALTER TABLE driver_documents DROP CONSTRAINT IF EXISTS driver_documents_document_type_check;
ALTER TABLE driver_documents DROP CONSTRAINT IF EXISTS driver_documents_verification_status_check;

-- Add new constraints
ALTER TABLE driver_documents 
ADD CONSTRAINT driver_documents_document_type_check 
CHECK (document_type IN (
  'drivingLicense',
  'vehicleRegistration',
  'insuranceCertificate',
  'driverPhoto',
  'vehiclePhoto'
));

ALTER TABLE driver_documents 
ADD CONSTRAINT driver_documents_status_check 
CHECK (status IN ('uploaded', 'under_review', 'approved', 'rejected'));

-- Update indexes
DROP INDEX IF EXISTS idx_driver_documents_status;
CREATE INDEX IF NOT EXISTS idx_driver_documents_status ON driver_documents (status);
CREATE INDEX IF NOT EXISTS idx_driver_documents_uploaded_at ON driver_documents (uploaded_at DESC);

-- Create the admin view
CREATE OR REPLACE VIEW admin_document_review_queue AS
SELECT 
    dd.id,
    dd.driver_id,
    u.first_name || ' ' || u.last_name as driver_name,
    u.email,
    u.phone,
    dd.document_type,
    dd.status,
    dd.uploaded_at,
    dd.file_path,
    EXTRACT(EPOCH FROM (NOW() - dd.uploaded_at))/3600 as hours_pending
FROM driver_documents dd
JOIN drivers d ON dd.driver_id = d.id
JOIN users u ON d.user_id = u.id
WHERE dd.status = 'under_review'
ORDER BY dd.uploaded_at ASC;

-- Update the verification summary function
CREATE OR REPLACE FUNCTION get_driver_verification_summary(driver_id_param UUID)
RETURNS TABLE (
    total_documents INTEGER,
    approved_documents INTEGER,
    rejected_documents INTEGER,
    pending_documents INTEGER,
    verification_percentage NUMERIC,
    overall_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_documents,
        COUNT(CASE WHEN status = 'approved' THEN 1 END)::INTEGER as approved_documents,
        COUNT(CASE WHEN status = 'rejected' THEN 1 END)::INTEGER as rejected_documents,
        COUNT(CASE WHEN status IN ('uploaded', 'under_review') THEN 1 END)::INTEGER as pending_documents,
        CASE 
            WHEN COUNT(*) = 0 THEN 0
            ELSE ROUND((COUNT(CASE WHEN status = 'approved' THEN 1 END) * 100.0 / 5), 2)
        END as verification_percentage,
        CASE 
            WHEN COUNT(CASE WHEN status = 'approved' THEN 1 END) = 5 THEN 'fully_verified'
            WHEN COUNT(CASE WHEN status = 'approved' THEN 1 END) > 0 THEN 'partially_verified'
            WHEN COUNT(*) > 0 THEN 'documents_uploaded'
            ELSE 'pending'
        END as overall_status
    FROM driver_documents 
    WHERE driver_id = driver_id_param;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE driver_documents IS 'Stores driver verification documents and their approval status (Updated for new system)';
COMMENT ON COLUMN driver_documents.document_type IS 'Type of document: drivingLicense, vehicleRegistration, insuranceCertificate, driverPhoto, vehiclePhoto';
COMMENT ON COLUMN driver_documents.status IS 'Document status: uploaded, under_review, approved, rejected';
COMMENT ON VIEW admin_document_review_queue IS 'Admin view showing documents pending review with driver details';
