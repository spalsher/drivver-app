-- Drivrr Database Schema (Simplified without PostGIS)
-- PostgreSQL database schema for ride-hailing app with fare haggling

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table for both customers and basic user info
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    profile_picture_url VARCHAR(500),
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    fcm_token VARCHAR(500), -- For push notifications
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Drivers table with vehicle and license information
CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    license_expiry DATE NOT NULL,
    vehicle_make VARCHAR(50) NOT NULL,
    vehicle_model VARCHAR(50) NOT NULL,
    vehicle_year INTEGER NOT NULL,
    vehicle_color VARCHAR(30) NOT NULL,
    plate_number VARCHAR(20) UNIQUE NOT NULL,
    vehicle_type VARCHAR(20) DEFAULT 'sedan' CHECK (vehicle_type IN ('sedan', 'suv', 'hatchback', 'luxury')),
    is_online BOOLEAN DEFAULT FALSE,
    current_latitude DECIMAL(10, 8), -- Latitude coordinate
    current_longitude DECIMAL(11, 8), -- Longitude coordinate
    heading DECIMAL(5,2), -- Direction the driver is facing (0-360 degrees)
    rating DECIMAL(3,2) DEFAULT 5.00 CHECK (rating >= 0 AND rating <= 5),
    total_trips INTEGER DEFAULT 0,
    total_earnings DECIMAL(10,2) DEFAULT 0.00,
    commission_rate DECIMAL(5,2) DEFAULT 15.00, -- Percentage commission
    is_approved BOOLEAN DEFAULT FALSE,
    approval_date TIMESTAMP,
    documents_verified BOOLEAN DEFAULT FALSE,
    background_check_passed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ride requests from customers
CREATE TABLE ride_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES users(id) ON DELETE CASCADE,
    pickup_latitude DECIMAL(10, 8) NOT NULL,
    pickup_longitude DECIMAL(11, 8) NOT NULL,
    pickup_address TEXT NOT NULL,
    destination_latitude DECIMAL(10, 8) NOT NULL,
    destination_longitude DECIMAL(11, 8) NOT NULL,
    destination_address TEXT NOT NULL,
    customer_fare_offer DECIMAL(10,2) NOT NULL,
    estimated_distance_km DECIMAL(8,2),
    estimated_duration_minutes INTEGER,
    ride_type VARCHAR(20) DEFAULT 'standard' CHECK (ride_type IN ('standard', 'premium', 'shared')),
    passenger_count INTEGER DEFAULT 1 CHECK (passenger_count >= 1 AND passenger_count <= 6),
    special_instructions TEXT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'haggling', 'accepted', 'driver_assigned', 'cancelled', 'expired')),
    accepted_driver_id UUID REFERENCES drivers(id),
    final_agreed_fare DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Haggling offers between drivers and customers
CREATE TABLE haggling_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_request_id UUID REFERENCES ride_requests(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    driver_fare_offer DECIMAL(10,2) NOT NULL,
    customer_counter_offer DECIMAL(10,2),
    driver_counter_offer DECIMAL(10,2),
    offer_round INTEGER DEFAULT 1, -- Track negotiation rounds
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'countered', 'accepted', 'rejected', 'expired')),
    expires_at TIMESTAMP NOT NULL,
    accepted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Completed trips
CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_request_id UUID REFERENCES ride_requests(id),
    customer_id UUID REFERENCES users(id),
    driver_id UUID REFERENCES drivers(id),
    final_fare DECIMAL(10,2) NOT NULL,
    commission_amount DECIMAL(10,2) NOT NULL,
    driver_earnings DECIMAL(10,2) NOT NULL,
    pickup_time TIMESTAMP,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    actual_distance_km DECIMAL(8,2),
    actual_duration_minutes INTEGER,
    route_polyline TEXT, -- Encoded polyline of the route taken
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    cancellation_reason TEXT,
    cancelled_by VARCHAR(20) CHECK (cancelled_by IN ('customer', 'driver', 'system')),
    customer_rating INTEGER CHECK (customer_rating >= 1 AND customer_rating <= 5),
    driver_rating INTEGER CHECK (driver_rating >= 1 AND driver_rating <= 5),
    customer_review TEXT,
    driver_review TEXT,
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    payment_method VARCHAR(20) DEFAULT 'cash' CHECK (payment_method IN ('cash', 'card', 'wallet')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Driver earnings and transaction history
CREATE TABLE earnings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES trips(id),
    amount DECIMAL(10,2) NOT NULL,
    commission DECIMAL(10,2) NOT NULL,
    net_amount DECIMAL(10,2) NOT NULL,
    transaction_type VARCHAR(20) DEFAULT 'trip_earning' CHECK (transaction_type IN ('trip_earning', 'bonus', 'penalty', 'withdrawal')),
    description TEXT,
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payment transactions
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID REFERENCES trips(id),
    customer_id UUID REFERENCES users(id),
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('cash', 'card', 'wallet')),
    stripe_payment_intent_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    failure_reason TEXT,
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User wallet for in-app payments
CREATE TABLE wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    balance DECIMAL(10,2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'USD',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Wallet transactions
CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('credit', 'debit')),
    source VARCHAR(50) NOT NULL, -- 'trip_payment', 'top_up', 'refund', etc.
    reference_id UUID, -- Can reference trip_id, payment_id, etc.
    description TEXT,
    balance_after DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Driver documents for verification
CREATE TABLE driver_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('license', 'vehicle_registration', 'insurance', 'identity')),
    document_url VARCHAR(500) NOT NULL,
    verification_status VARCHAR(20) DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMP,
    rejection_reason TEXT,
    expires_at DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Push notifications log
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    data JSONB, -- Additional data for the notification
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP
);

-- System settings and configurations
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_drivers_user_id ON drivers(user_id);
CREATE INDEX idx_drivers_location ON drivers(current_latitude, current_longitude);
CREATE INDEX idx_drivers_online ON drivers(is_online);
CREATE INDEX idx_ride_requests_customer ON ride_requests(customer_id);
CREATE INDEX idx_ride_requests_status ON ride_requests(status);
CREATE INDEX idx_ride_requests_pickup ON ride_requests(pickup_latitude, pickup_longitude);
CREATE INDEX idx_haggling_ride_request ON haggling_offers(ride_request_id);
CREATE INDEX idx_haggling_driver ON haggling_offers(driver_id);
CREATE INDEX idx_trips_customer ON trips(customer_id);
CREATE INDEX idx_trips_driver ON trips(driver_id);
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_earnings_driver ON earnings(driver_id);
CREATE INDEX idx_payments_trip ON payments(trip_id);
CREATE INDEX idx_wallet_user ON wallets(user_id);
CREATE INDEX idx_wallet_transactions_wallet ON wallet_transactions(wallet_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);

-- Insert default system settings
INSERT INTO system_settings (setting_key, setting_value, description) VALUES
('max_haggling_rounds', '3', 'Maximum number of haggling rounds allowed'),
('haggling_timeout_minutes', '5', 'Time limit for each haggling round in minutes'),
('driver_search_radius_km', '10', 'Radius in kilometers to search for drivers'),
('max_ride_request_time_minutes', '15', 'Maximum time a ride request stays active'),
('commission_rate_percentage', '15', 'Default commission rate for drivers'),
('minimum_fare', '5.00', 'Minimum fare amount'),
('maximum_fare', '500.00', 'Maximum fare amount'),
('app_version', '1.0.0', 'Current app version'),
('maintenance_mode', 'false', 'Whether the app is in maintenance mode');

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ride_requests_updated_at BEFORE UPDATE ON ride_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_haggling_offers_updated_at BEFORE UPDATE ON haggling_offers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_trips_updated_at BEFORE UPDATE ON trips FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_wallets_updated_at BEFORE UPDATE ON wallets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
