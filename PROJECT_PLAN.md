# Drivrr - Indrive-Style Ride Hailing App Development Plan

## Project Overview
A comprehensive ride-hailing application similar to Indrive, featuring fare haggling, cross-platform support (Android/iOS), and modern UI design using Flutter and MapTiler maps.

## Key Features & Requirements
- **No subscription-based services** - Using free alternatives
- **Cross-platform** - Flutter for Android & iOS
- **Separate apps** - Driver app and Customer app
- **Core functionality** - Fare haggling, ride booking, real-time tracking
- **Maps** - MapTiler (free tier) instead of Google Maps
- **Modern UI** - Clean, innovative design without being flashy

## Tech Stack

### Frontend
- **Framework**: Flutter 3.x
- **Language**: Dart
- **State Management**: Riverpod/Provider
- **Navigation**: Go Router
- **UI Components**: Custom widgets + Material 3 design
- **Maps**: MapTiler SDK for Flutter
- **Real-time**: WebSockets/Socket.io client

### Backend
- **Runtime**: Node.js with Express
- **Database**: PostgreSQL
- **Real-time**: Socket.io
- **Authentication**: JWT tokens
- **File Storage**: Local file system
- **Payment**: Stripe (one-time setup, no monthly fees)
- **Maps API**: MapTiler API (free tier: 100k requests/month)

### DevOps & Tools
- **Version Control**: Git
- **Environment**: Docker for local development
- **API Documentation**: Postman/Swagger
- **Testing**: Flutter test framework

## App Architecture

### Customer App Structure
```
customer_app/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   ├── utils/
│   │   ├── services/
│   │   └── models/
│   ├── features/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── booking/
│   │   ├── haggling/
│   │   ├── trip/
│   │   ├── profile/
│   │   └── payment/
│   ├── shared/
│   │   ├── widgets/
│   │   ├── themes/
│   │   └── providers/
│   └── main.dart
```

### Driver App Structure
```
driver_app/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   ├── utils/
│   │   ├── services/
│   │   └── models/
│   ├── features/
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── requests/
│   │   ├── haggling/
│   │   ├── trip/
│   │   ├── earnings/
│   │   └── profile/
│   ├── shared/
│   │   ├── widgets/
│   │   ├── themes/
│   │   └── providers/
│   └── main.dart
```

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    profile_picture_url VARCHAR(500),
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Drivers Table
```sql
CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    vehicle_make VARCHAR(50) NOT NULL,
    vehicle_model VARCHAR(50) NOT NULL,
    vehicle_year INTEGER NOT NULL,
    vehicle_color VARCHAR(30) NOT NULL,
    plate_number VARCHAR(20) UNIQUE NOT NULL,
    is_online BOOLEAN DEFAULT FALSE,
    current_location POINT,
    rating DECIMAL(3,2) DEFAULT 5.00,
    total_trips INTEGER DEFAULT 0,
    is_approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Ride Requests Table
```sql
CREATE TABLE ride_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES users(id) ON DELETE CASCADE,
    pickup_location POINT NOT NULL,
    pickup_address TEXT NOT NULL,
    destination_location POINT NOT NULL,
    destination_address TEXT NOT NULL,
    customer_fare_offer DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL
);
```

### Haggling Table
```sql
CREATE TABLE haggling_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_request_id UUID REFERENCES ride_requests(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
    driver_fare_offer DECIMAL(10,2) NOT NULL,
    customer_counter_offer DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Trips Table
```sql
CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_request_id UUID REFERENCES ride_requests(id),
    customer_id UUID REFERENCES users(id),
    driver_id UUID REFERENCES drivers(id),
    final_fare DECIMAL(10,2) NOT NULL,
    pickup_time TIMESTAMP,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    distance_km DECIMAL(8,2),
    duration_minutes INTEGER,
    status VARCHAR(20) DEFAULT 'active',
    customer_rating INTEGER CHECK (customer_rating >= 1 AND customer_rating <= 5),
    driver_rating INTEGER CHECK (driver_rating >= 1 AND driver_rating <= 5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Key Features Implementation

### 1. Fare Haggling System
- Customer sets initial price when booking
- Drivers can accept or counter-offer
- Real-time negotiation with time limits
- Automatic matching if prices align
- Maximum 3 counter-offers per party

### 2. Real-time Location Tracking
- WebSocket connections for live updates
- MapTiler for map rendering and routing
- Efficient location updates (every 5 seconds when active)
- Battery optimization for background tracking

### 3. Smart Matching Algorithm
- Distance-based driver selection
- Rating considerations
- Driver availability status
- Fair distribution of ride requests

### 4. Payment Integration
- Stripe for card payments
- Cash payment option
- In-app wallet system
- Automatic fare calculation

### 5. Rating & Review System
- Mutual rating system
- Review comments
- Rating-based driver/customer filtering
- Performance analytics

## UI/UX Design Principles

### Design Theme
- **Clean & Modern**: Minimalist design with plenty of white space
- **Intuitive Navigation**: Bottom tab navigation with clear iconography
- **Accessibility**: High contrast ratios, proper text sizing
- **Brand Colors**: 
  - Primary: #2563EB (Blue)
  - Secondary: #059669 (Green)
  - Accent: #DC2626 (Red for alerts)
  - Neutral: #64748B (Gray)

### Key Screens Design

#### Customer App Screens
1. **Onboarding** - Introduction slides with app benefits
2. **Authentication** - Login/Register with phone/email
3. **Home** - Map view with destination search
4. **Booking** - Set pickup/destination, initial fare offer
5. **Haggling** - Real-time negotiation interface
6. **Trip Active** - Live tracking with driver info
7. **Payment** - Multiple payment options
8. **History** - Past trips and receipts
9. **Profile** - User settings and preferences

#### Driver App Screens
1. **Dashboard** - Earnings overview and online status
2. **Requests** - Incoming ride requests with details
3. **Haggling** - Fare negotiation interface
4. **Navigation** - Turn-by-turn directions during trip
5. **Earnings** - Daily/weekly/monthly reports
6. **Profile** - Driver details and vehicle info
7. **Documents** - License and vehicle documentation

## Development Phases

### Phase 1: Core Setup (Week 1-2)
- [ ] Set up Flutter projects for both apps
- [ ] Configure MapTiler SDK
- [ ] Set up backend with Node.js/Express
- [ ] Design and implement database schema
- [ ] Basic authentication system
- [ ] Map integration and location services

### Phase 2: Core Features (Week 3-5)
- [ ] User registration and profile management
- [ ] Driver onboarding and verification
- [ ] Basic ride booking functionality
- [ ] Real-time location tracking
- [ ] Map rendering and route calculation

### Phase 3: Haggling System (Week 6-7)
- [ ] Fare haggling interface
- [ ] Real-time WebSocket communication
- [ ] Negotiation logic and rules
- [ ] Automatic matching system
- [ ] Time-based offer expiration

### Phase 4: Trip Management (Week 8-9)
- [ ] Trip lifecycle management
- [ ] Live trip tracking
- [ ] Driver-customer communication
- [ ] Trip completion and payment
- [ ] Rating and review system

### Phase 5: Advanced Features (Week 10-11)
- [ ] Payment gateway integration
- [ ] Push notifications
- [ ] Trip history and receipts
- [ ] Driver earnings dashboard
- [ ] Admin panel for management

### Phase 6: Testing & Polish (Week 12)
- [ ] End-to-end testing
- [ ] Performance optimization
- [ ] UI/UX refinements
- [ ] Security audit
- [ ] App store preparation

## Security Considerations

### Data Protection
- JWT tokens for authentication
- Password hashing with bcrypt
- Input validation and sanitization
- Rate limiting for API endpoints
- HTTPS enforcement

### Location Privacy
- Location data encryption
- Minimal location history storage
- User consent for location tracking
- Option to delete location history

### Payment Security
- PCI compliance through Stripe
- No storage of sensitive card data
- Secure payment tokenization
- Fraud detection mechanisms

## Deployment Strategy

### Development Environment
- Local Docker containers
- PostgreSQL database
- MapTiler development API keys
- Hot reload for Flutter development

### Production Considerations
- VPS hosting (DigitalOcean/Linode)
- PostgreSQL with automated backups
- SSL certificates (Let's Encrypt)
- CDN for static assets
- Monitoring and logging

## Cost Analysis (Free/Low-Cost Approach)

### Monthly Costs (Estimated)
- **MapTiler**: Free tier (100k requests/month)
- **VPS Hosting**: $20-40/month
- **Database Storage**: Included with VPS
- **SSL Certificate**: Free (Let's Encrypt)
- **Stripe Processing**: 2.9% + 30¢ per transaction
- **Total Fixed Costs**: $20-40/month

### Scaling Considerations
- MapTiler paid plans start at $35/month for 500k requests
- Additional VPS resources as user base grows
- Database optimization for large datasets
- CDN implementation for better performance

## Success Metrics

### User Engagement
- Daily/Monthly Active Users
- Average session duration
- Ride completion rate
- User retention rate

### Business Metrics
- Average fare per trip
- Driver utilization rate
- Customer satisfaction scores
- Revenue per trip

### Technical Metrics
- App performance (loading times)
- API response times
- Crash rates
- Battery usage optimization

## Risk Mitigation

### Technical Risks
- **MapTiler API limits**: Monitor usage, implement caching
- **Real-time performance**: Optimize WebSocket connections
- **Battery drain**: Implement smart location tracking
- **Scalability**: Design for horizontal scaling

### Business Risks
- **Driver adoption**: Competitive commission rates
- **Customer trust**: Strong rating system and verification
- **Market competition**: Unique haggling feature differentiation
- **Regulatory compliance**: Research local transportation laws

## Next Steps

1. **Environment Setup**: Install Flutter, set up development environment
2. **API Keys**: Register for MapTiler and Stripe accounts
3. **Repository Structure**: Initialize Git repositories for both apps
4. **Database Setup**: Configure PostgreSQL database
5. **Basic Authentication**: Implement user registration/login
6. **Map Integration**: Add MapTiler to Flutter apps
7. **Backend API**: Create initial API endpoints

---

**Note**: This plan serves as a living document that will be updated as development progresses. Each phase includes specific deliverables and can be adjusted based on testing feedback and user requirements.

## Contact & Communication
- Regular progress updates will be documented in this file
- Feature completions will be marked with checkboxes
- Any architectural changes will be reflected in this plan
- Weekly reviews to assess progress and adjust timelines
