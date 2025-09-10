const io = require('socket.io-client');

console.log('🧪 Testing ride request flow...');

// Simulate customer connection
const customerSocket = io('http://localhost:3000', {
  transports: ['websocket']
});

// Simulate driver connection
const driverSocket = io('http://localhost:3000', {
  transports: ['websocket']
});

let customerConnected = false;
let driverConnected = false;

// Customer connection
customerSocket.on('connect', () => {
  console.log('👤 Customer connected');
  customerConnected = true;
  
  // Join customer room
  customerSocket.emit('join_user_room', { userId: 'customer_123' });
  
  // Wait for both connections then send ride request
  checkAndSendRideRequest();
});

// Driver connection
driverSocket.on('connect', () => {
  console.log('🚗 Driver connected');
  driverConnected = true;
  
  // Join driver room
  driverSocket.emit('join_driver_room', { 
    driverId: 'driver_123', 
    userType: 'driver' 
  });
  
  // Set driver online
  driverSocket.emit('driver_status_update', {
    driverId: 'driver_123',
    isOnline: true
  });
  
  // Wait for both connections then send ride request
  checkAndSendRideRequest();
});

// Listen for ride requests on driver side
driverSocket.on('new_ride_request', (data) => {
  console.log('🎯 Driver received ride request:', data);
  
  // Send an offer back
  setTimeout(() => {
    console.log('💰 Driver sending offer...');
    driverSocket.emit('driver_offer', {
      rideId: data.rideId,
      customerId: 'customer_123',
      driverId: 'driver_123',
      offer: 300
    });
  }, 2000);
});

// Listen for driver offers on customer side
customerSocket.on('driver_offer', (data) => {
  console.log('💵 Customer received offer:', data);
});

function checkAndSendRideRequest() {
  if (customerConnected && driverConnected) {
    console.log('📡 Both connected, sending ride request...');
    
    setTimeout(() => {
      const rideRequest = {
        pickup: 'Test Pickup Location',
        destination: 'Test Destination',
        pickupLat: 24.8607,
        pickupLng: 67.0011,
        destLat: 24.8138,
        destLng: 67.0300,
        customerFareOffer: 250,
        vehicleType: 'economy',
        distance: 5.5,
        duration: 15,
        customerId: 'customer_123'
      };
      
      console.log('🚗 Creating ride request:', rideRequest);
      customerSocket.emit('create_ride_request', rideRequest);
    }, 1000);
  }
}

// Error handling
customerSocket.on('connect_error', (error) => {
  console.log('❌ Customer connection error:', error);
});

driverSocket.on('connect_error', (error) => {
  console.log('❌ Driver connection error:', error);
});

// Keep script running
setTimeout(() => {
  console.log('🏁 Test completed');
  process.exit(0);
}, 10000);
