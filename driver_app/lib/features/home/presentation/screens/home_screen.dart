import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider;
import 'dart:async';
import '../../../requests/presentation/screens/ride_requests_screen.dart';
import '../../../earnings/presentation/screens/earnings_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../widgets/driver_map_widget.dart';
import '../../../../core/services/native_websocket_service.dart';
import '../../../../core/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isOnline = false;
  bool _isVerified = true; // TODO: Get from backend
  Timer? _earningsTimer;
  
  // Driver stats (TODO: Get from backend)
  double _todayEarnings = 850.0;
  int _todayTrips = 12;
  double _rating = 4.8;
  int _totalTrips = 847;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Widget> _screens = [
    const DriverMapScreen(),
    const RideRequestsScreen(),
    const EarningsScreen(), 
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _startEarningsSimulation();
    _initializeWebSocket();
  }
  
  void _initializeWebSocket() async {
    try {
      // Get real driver ID from auth
      final authProvider = provider.Provider.of<AuthProvider>(context, listen: false);
      final driverId = await authProvider.getDriverId() ?? 'driver_123';
      print('🔑 Using driver ID for WebSocket: $driverId');
      
      // Connect to Go WebSocket backend  
      await DriverNativeWebSocketService.instance.connect(driverId);
      
      // Listen for ride requests
      DriverNativeWebSocketService.instance.rideRequests.listen((request) {
        print('🚗 New ride request from Go backend: $request');
        _showRideRequestNotification(request);
      });
      
      // Listen for connection status
      DriverNativeWebSocketService.instance.connectionStatus.listen((status) {
        print('🔌 Driver Go WebSocket status: $status');
        if (status == 'connected') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Connected to Go ride network'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      print('❌ Failed to initialize driver Go WebSocket: $e');
    }
  }
  
  void _showRideRequestNotification(Map<String, dynamic> request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚗 New Ride Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${request['pickup'] ?? 'Unknown'}'),
            Text('To: ${request['destination'] ?? 'Unknown'}'),
            Text('Distance: ${request['distance'] ?? 'Unknown'} km'),
            Text('Customer Offer: PKR ${request['customerFareOffer'] ?? 'Unknown'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendRideOffer(request);
            },
            child: const Text('Make Offer'),
          ),
        ],
      ),
    );
  }
  
  void _sendRideOffer(Map<String, dynamic> request) {
    // Show fare input dialog
    showDialog(
      context: context,
      builder: (context) {
        final fareController = TextEditingController(
          text: (request['customerFareOffer']?.toDouble() ?? 250.0).toString(),
        );
        return AlertDialog(
          title: const Text('Your Fare Offer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fareController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Fare (PKR)',
                  prefixText: 'PKR ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                final fare = double.tryParse(fareController.text) ?? 250.0;
                DriverNativeWebSocketService.instance.sendRideOffer(
                  rideId: request['rideId'] ?? '',
                  customerId: request['customerId'] ?? '',
                  fareOffer: fare,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Offer sent: PKR $fare')),
                );
              },
              child: const Text('Send Offer'),
            ),
          ],
        );
      },
    );
  }
  
  void _startEarningsSimulation() {
    _earningsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isOnline && mounted) {
        setState(() {
          _todayEarnings += 25.0 + (DateTime.now().millisecond % 50);
          if (DateTime.now().second % 120 == 0) {
            _todayTrips++;
          }
        });
      }
    });
  }
  
  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });
    
    // Update driver status via Go WebSocket
    DriverNativeWebSocketService.instance.setDriverStatus(_isOnline);
    
    if (_isOnline) {
      _pulseController.repeat();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚗 You are now online and available for rides'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } else {
      _pulseController.stop();
      _pulseController.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📵 You are now offline'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVerified) {
      return _buildVerificationPendingScreen();
    }
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
  
  Widget _buildVerificationPendingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pending,
                  size: 50,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verification Pending',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your documents are under review. We\'ll notify you once approved.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/verification'),
                child: const Text('View Documents'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _earningsTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
}

// Driver Map Screen
class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  bool _isOnline = false;
  double _todayEarnings = 850.0;
  int _todayTrips = 12;
  
  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });
  }
  
  void _onRideRequestTapped(Map<String, dynamic> request) {
    // Show ride request details bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RideRequestBottomSheet(
        request: request,
        onAccept: () => _acceptRideRequest(request),
        onDecline: () => Navigator.of(context).pop(),
      ),
    );
  }
  
  void _acceptRideRequest(Map<String, dynamic> request) {
    Navigator.of(context).pop();
    // TODO: Navigate to ride details screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accepted ride to ${request['destinationAddress']}'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Driver Map with nearby ride requests
          DriverMapWidget(
            isOnline: _isOnline,
            onRideRequestTapped: _onRideRequestTapped,
          ),
          
          // Status and earnings header
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Online/Offline toggle
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _isOnline ? const Color(0xFF4CAF50) : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                        onChanged: (value) => _toggleOnlineStatus(),
                        activeColor: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Earnings',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'PKR ${_todayEarnings.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trips Today',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$_todayTrips trips',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Go Online/Offline button
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 60,
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0xFF4CAF50) : const Color(0xFF1B5E20),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: (_isOnline ? const Color(0xFF4CAF50) : const Color(0xFF1B5E20)).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleOnlineStatus,
                  borderRadius: BorderRadius.circular(30),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isOnline ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOnline ? 'Go Offline' : 'Go Online',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Ride Request Bottom Sheet
class _RideRequestBottomSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  
  const _RideRequestBottomSheet({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_taxi,
                    color: Colors.orange[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Ride Request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${request['distance']}km • ${request['estimatedDuration']}min',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PKR ${request['customerOffer']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Customer info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1B5E20),
                    child: Text(
                      request['customerName'].substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['customerName'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${request['passengerCount']} passenger${request['passengerCount'] > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Route details
            Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        request['pickupAddress'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  height: 20,
                  width: 2,
                  color: Colors.grey[300],
                ),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        request['destinationAddress'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
