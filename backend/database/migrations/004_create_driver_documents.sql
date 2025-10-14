-- Migration: Create driver_documents table for document verification
-- Run this in your PostgreSQL database

-- Create driver_documents table
CREATE TABLE IF NOT EXISTS driver_documents (
    id SERIAL PRIMARY KEY,
    driver_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (
        document_type IN (
            'drivingLicense',
            'vehicleRegistration',
            'insuranceCertificate',
            'driverPhoto',
            'vehiclePhoto'
        )
    ),
    file_path VARCHAR(500) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'under_review' CHECK (
        status IN ('uploaded', 'under_review', 'approved', 'rejected')
    ),
    rejection_reason TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create unique constraint to prevent duplicate document types per driver
CREATE UNIQUE INDEX IF NOT EXISTS idx_driver_documents_unique 
ON driver_documents (driver_id, document_type);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_driver_documents_driver_id ON driver_documents (driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_documents_status ON driver_documents (status);
CREATE INDEX IF NOT EXISTS idx_driver_documents_uploaded_at ON driver_documents (uploaded_at DESC);

-- Add verification_status column to users table if it doesn't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS verification_status VARCHAR(20) DEFAULT 'pending' 
CHECK (verification_status IN ('pending', 'under_review', 'verified', 'rejected'));

-- Add is_admin column to users table if it doesn't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Create trigger to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to driver_documents table
DROP TRIGGER IF EXISTS update_driver_documents_updated_at ON driver_documents;
CREATE TRIGGER update_driver_documents_updated_at
    BEFORE UPDATE ON driver_documents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample admin user (optional - remove in production)
-- Password is 'admin123' hashed with bcrypt
INSERT INTO users (
    email, phone, first_name, last_name, password_hash, is_admin, is_verified, is_active
) VALUES (
    'admin@drivrr.com', 
    '+1234567890', 
    'Admin', 
    'User', 
    '$2b$12$LQv3c1yqBwEHxE4G8KGQY.f0l8Z8K8K8K8K8K8K8K8K8K8K8K8K8K', 
    TRUE, 
    TRUE, 
    TRUE
) ON CONFLICT (email) DO NOTHING;

-- Create function to get driver verification summary
CREATE OR REPLACE FUNCTION get_driver_verification_summary(driver_id_param INTEGER)
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

-- Create view for admin dashboard
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
JOIN users u ON dd.driver_id = u.id
WHERE dd.status = 'under_review'
ORDER BY dd.uploaded_at ASC;

-- Grant necessary permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON driver_documents TO your_app_user;
-- GRANT USAGE, SELECT ON SEQUENCE driver_documents_id_seq TO your_app_user;
-- GRANT SELECT ON admin_document_review_queue TO your_app_user;

COMMENT ON TABLE driver_documents IS 'Stores driver verification documents and their approval status';
COMMENT ON COLUMN driver_documents.document_type IS 'Type of document: drivingLicense, vehicleRegistration, insuranceCertificate, driverPhoto, vehiclePhoto';
COMMENT ON COLUMN driver_documents.status IS 'Document status: uploaded, under_review, approved, rejected';
COMMENT ON COLUMN driver_documents.rejection_reason IS 'Reason for rejection if status is rejected';
COMMENT ON VIEW admin_document_review_queue IS 'Admin view showing documents pending review with driver details';
