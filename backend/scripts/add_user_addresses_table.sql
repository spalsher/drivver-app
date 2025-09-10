-- Add user_addresses table for saved addresses
CREATE TABLE IF NOT EXISTS user_addresses (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'home', 'work', 'favorite'
    address TEXT NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    label VARCHAR(100), -- Custom label like "Mom's house", "Office", etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_addresses_user_id ON user_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_user_addresses_type ON user_addresses(type);

-- Add profile_photo and address columns to users table if they don't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS profile_photo VARCHAR(500),
ADD COLUMN IF NOT EXISTS home_address TEXT,
ADD COLUMN IF NOT EXISTS work_address TEXT;

-- Update existing schema to match our needs
UPDATE users SET 
    first_name = COALESCE(first_name, 'User'),
    last_name = COALESCE(last_name, 'Name')
WHERE first_name IS NULL OR last_name IS NULL;
