-- Add gender field to users table for theme customization and safety features
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS gender VARCHAR(10) CHECK (gender IN ('male', 'female', 'other'));

-- Add safety preferences for female users
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS safety_preferences JSONB DEFAULT '{}';

-- Add theme preference
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS theme_preference VARCHAR(20) DEFAULT 'auto';

-- Create index for gender-based queries
CREATE INDEX IF NOT EXISTS idx_users_gender ON users(gender);

-- Update existing users to have default gender (can be updated via profile)
UPDATE users SET gender = 'male' WHERE gender IS NULL;
