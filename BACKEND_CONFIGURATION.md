# Backend Configuration Guide

## Dual Backend Architecture

The Drivrr app uses a **dual backend architecture** to optimize performance and separate concerns:

### 1. Node.js Backend (Port 3000)
**Purpose**: Authentication, User Management, HTTP API  
**Location**: `/backend/`  
**Responsibilities**:
- 🔐 **OTP Authentication** - Phone number verification and login
- 👥 **User Management** - Profile, addresses, ride history
- 💳 **Payment Processing** - Transaction handling
- 📊 **Data Management** - PostgreSQL database operations
- 🔒 **JWT Token Management** - Authentication tokens

**Endpoints**:
- `http://localhost:3000/api/auth/*` - Authentication (OTP send/verify)
- `http://localhost:3000/api/users/*` - User profile and data
- `http://localhost:3000/api/rides/*` - Ride history and management

### 2. Go Backend (Port 8081)
**Purpose**: Real-time Communication, WebSocket Management  
**Location**: `/go-backend/`  
**Responsibilities**:
- 🔄 **Real-time Ride Matching** - Live driver-customer connections
- 📡 **WebSocket Management** - Persistent connections for both apps
- 🚗 **Live Location Updates** - Driver position tracking
- 💬 **Ride Negotiations** - Haggling system
- ⚡ **High Performance** - Concurrent connection handling

**WebSocket Endpoint**:
- `ws://localhost:8081/ws` - WebSocket connections for real-time features

## Configuration Files

### Flutter Apps Configuration
Both customer and driver apps are configured in their respective `app_constants.dart`:

```dart
// API Configuration
static const String baseUrl = 'http://192.168.20.67:3000/api'; // Node.js backend for OTP/Auth
static const String socketUrl = 'ws://192.168.20.67:8081/ws'; // Go backend for WebSocket
```

### Starting Both Backends

1. **Start Node.js Backend (Terminal 1)**:
   ```bash
   cd backend
   npm start
   ```

2. **Start Go Backend (Terminal 2)**:
   ```bash
   cd go-backend
   go run .
   ```

### Health Check Commands

```bash
# Test Node.js backend
curl http://localhost:3000/api/health

# Test Go backend  
curl http://localhost:8081/api/health
```

## Why This Architecture?

### Node.js Strengths:
- **Mature ecosystem** for authentication and OTP services
- **Rich database libraries** for PostgreSQL operations
- **Excellent HTTP/REST API** handling
- **JWT and security middleware** readily available

### Go Strengths:
- **Superior concurrency** for handling many WebSocket connections
- **Low latency** for real-time features
- **High performance** for live location updates
- **Efficient memory usage** for persistent connections

## Port Summary
- **3000**: Node.js (HTTP API, OTP, User Management)
- **8081**: Go (WebSocket, Real-time Communication)
- **5432**: PostgreSQL Database

## Network Configuration
Replace `192.168.20.67` with your actual network IP address for testing on physical devices.

## Security Notes
- Both backends connect to the same PostgreSQL database
- JWT tokens are managed by Node.js backend
- Go backend handles real-time features without authentication for development
- In production, implement proper WebSocket authentication
