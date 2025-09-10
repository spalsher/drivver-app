-- Create rides table for storing ride information
CREATE TABLE IF NOT EXISTS rides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    pickup_address TEXT NOT NULL,
    pickup_latitude DECIMAL(10,8),
    pickup_longitude DECIMAL(11,8),
    destination_address TEXT NOT NULL,
    destination_latitude DECIMAL(10,8),
    destination_longitude DECIMAL(11,8),
    distance_km DECIMAL(6,2),
    duration_minutes INTEGER,
    fare_amount DECIMAL(10,2),
    final_fare DECIMAL(10,2),
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, accepted, in_progress, completed, cancelled
    payment_status VARCHAR(50) DEFAULT 'pending', -- pending, paid, failed, refunded
    payment_method VARCHAR(50), -- cash, card, wallet
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    customer_review TEXT,
    driver_review TEXT,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_rides_customer_id ON rides(customer_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_created_at ON rides(created_at);

-- Create ride_offers table for haggling system
CREATE TABLE IF NOT EXISTS ride_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    offered_fare DECIMAL(10,2) NOT NULL,
    message TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, accepted, rejected, expired
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for ride_offers
CREATE INDEX IF NOT EXISTS idx_ride_offers_ride_id ON ride_offers(ride_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_driver_id ON ride_offers(driver_id);
CREATE INDEX IF NOT EXISTS idx_ride_offers_status ON ride_offers(status);
