import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../../core/services/native_websocket_service.dart';

class HagglingScreen extends StatefulWidget {
  const HagglingScreen({super.key});

  @override
  State<HagglingScreen> createState() => _HagglingScreenState();
}

class _HagglingScreenState extends State<HagglingScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _driverOffers = [];
  Timer? _offerTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  bool _isSearching = true;
  Map<String, dynamic>? _rideData;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for searching
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start countdown
    _startCountdown();
    
    // Connect to WebSocket (but don't create ride request yet)
    _connectToWebSocket();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get ride data passed from previous screen
    final extra = GoRouterState.of(context).extra;
    print('🔍 HagglingScreen: Received route data: $extra');
    if (extra != null && extra is Map<String, dynamic>) {
      _rideData = extra;
      print('✅ HagglingScreen: Route data set successfully: $_rideData');
      
      // Now that we have ride data, create the ride request
      Future.delayed(const Duration(seconds: 2), () {
        _createRideRequest();
      });
    } else {
      print('❌ HagglingScreen: No route data received or invalid format');
    }
  }
  
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        if (_driverOffers.isEmpty) {
          _showNoDriversDialog();
        }
      }
    });
  }
  
  void _connectToWebSocket() async {
    try {
      print('🔌 HagglingScreen: Connecting to Go WebSocket backend...');
      
      // Connect to Go backend
      await NativeWebSocketService.instance.connect('customer_123');
      
      // Wait for connection to establish
      await Future.delayed(const Duration(seconds: 1));
      
      print('🔌 HagglingScreen: Go WebSocket connection status: ${NativeWebSocketService.instance.isConnected}');
      
      // Listen for driver offers - REAL TIME ONLY!
      NativeWebSocketService.instance.driverOffers.listen((offer) {
        print('🎯 HagglingScreen: REAL driver offer received from Go backend: $offer');
        if (mounted) {
          setState(() {
            _isSearching = false;
            _driverOffers.add({
              'id': offer['driverId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'name': 'Driver ${offer['driverId']?.toString().substring(0, 8) ?? 'Unknown'}',
              'rating': 4.5 + (math.Random().nextDouble() * 0.5),
              'trips': 100 + math.Random().nextInt(400),
              'vehicleModel': _getRandomVehicle(),
              'vehicleNumber': 'KHI-${math.Random().nextInt(9999)}',
              'price': (offer['offer'] as num?)?.toInt() ?? 250,
              'arrivalTime': 3 + math.Random().nextInt(7),
              'avatar': 'https://i.pravatar.cc/150?img=${math.Random().nextInt(50)}',
              'isCounterOffer': false,
              'driverId': offer['driverId'],
              'rideId': offer['rideId'],
            });
          });
        }
      });
      
      // Listen for connection status
      NativeWebSocketService.instance.connectionStatus.listen((status) {
        print('🔌 HagglingScreen: Connection status changed: $status');
      });
      
      // Listen for driver assignment and location updates
      NativeWebSocketService.instance.rideUpdates.listen((update) {
        print('🔄 HagglingScreen: Ride update received: $update');
        
        if (update['type'] == 'driver_assigned') {
          print('🚗 Driver assigned! ETA: ${update['driverETA']} minutes');
          
          // Navigate to active trip with driver details
          if (mounted) {
            context.push('/active-trip', extra: {
              'rideId': update['rideId'],
              'driverId': update['driverId'],
              'driverName': update['driverName'],
              'driverLat': update['driverLat'],
              'driverLng': update['driverLng'],
              'driverETA': update['driverETA'],
              'finalPrice': update['finalPrice'].toString(),
              'status': 'driver_assigned',
              'pickup': _rideData?['pickup'] ?? 'Current Location',
              'destination': _rideData?['destination'] ?? 'Destination',
              'pickupLat': _rideData?['pickupLat'],
              'pickupLng': _rideData?['pickupLng'],
              'destinationLat': _rideData?['destLat'],
              'destinationLng': _rideData?['destLng'],
            });
          }
        }
      });
      
    } catch (e) {
      print('❌ HagglingScreen: Go WebSocket connection error: $e');
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to connect to ride network. Please check your connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  void _createRideRequest() {
    print('🚗 HagglingScreen: _createRideRequest called');
    print('🚗 HagglingScreen: _rideData is null: ${_rideData == null}');
    
    if (_rideData != null) {
      print('🚗 HagglingScreen: Creating ride request with data: $_rideData');
      
      final rideRequest = {
        'pickup': _rideData!['pickup'] ?? 'Current Location',
        'destination': _rideData!['destination'] ?? 'Destination',
        'pickupLat': _rideData!['pickupLat'] ?? 24.8607,
        'pickupLng': _rideData!['pickupLng'] ?? 67.0011,
        'destLat': _rideData!['destLat'] ?? 24.8138,
        'destLng': _rideData!['destLng'] ?? 67.0300,
        'customerFareOffer': _rideData!['estimatedFare'] ?? 250,
        'vehicleType': _rideData!['vehicleType'] ?? 'economy',
        'distance': _rideData!['actualDistance'] ?? 5.5,
        'duration': _rideData!['actualDuration'] ?? 15,
        'customerId': 'customer_123', // TODO: Get from auth
      };
      
      print('🚗 HagglingScreen: Final ride request: $rideRequest');
      print('🚗 HagglingScreen: Calling NativeWebSocketService.createRideRequest...');
      
      NativeWebSocketService.instance.createRideRequest(rideRequest);
      print('🚗 HagglingScreen: NativeWebSocketService.createRideRequest call completed');
    } else {
      print('❌ HagglingScreen: Cannot create ride request - _rideData is null!');
    }
  }
  
  void _simulateDriverOffers() {
    final baseFare = _rideData?['estimatedFare'] ?? 250;
    final random = math.Random();
    
    // Generate random driver offers as fallback
    _offerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_driverOffers.length < 3) {
        final variation = random.nextInt(100) - 50;
        final offerPrice = baseFare + variation;
        
        setState(() {
          _isSearching = false;
          _driverOffers.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'name': _getRandomDriverName(),
            'rating': (4.0 + random.nextDouble()).clamp(4.0, 5.0),
            'trips': random.nextInt(500) + 100,
            'vehicleModel': _getRandomVehicle(),
            'vehicleNumber': 'KHI-${random.nextInt(9999)}',
            'price': offerPrice,
            'arrivalTime': random.nextInt(5) + 2,
            'avatar': 'https://i.pravatar.cc/150?img=${random.nextInt(50)}',
            'isCounterOffer': false,
          });
        });
      } else {
        timer.cancel();
      }
    });
  }
  
  String _getRandomDriverName() {
    final names = ['Ahmed Khan', 'Ali Hassan', 'Usman Shah', 'Bilal Ahmed', 'Fahad Ali'];
    return names[math.Random().nextInt(names.length)];
  }
  
  String _getRandomVehicle() {
    final vehicles = ['Toyota Corolla', 'Honda Civic', 'Suzuki Cultus', 'Suzuki Swift', 'Honda City'];
    return vehicles[math.Random().nextInt(vehicles.length)];
  }
  
  void _acceptDriverOffer(Map<String, dynamic> offer) {
    // Cancel timers
    _offerTimer?.cancel();
    _countdownTimer?.cancel();
    
    // Send acceptance to Go backend with location data
    NativeWebSocketService.instance.acceptOffer(
      rideId: offer['rideId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      driverId: offer['driverId'] ?? 'driver_123',
      finalPrice: (offer['price']?.toInt() ?? 250).toDouble(),
      pickupLat: _rideData?['pickupLat'] ?? 24.8607,
      pickupLng: _rideData?['pickupLng'] ?? 67.0011,
      destLat: _rideData?['destLat'] ?? 24.8138,
      destLng: _rideData?['destLng'] ?? 67.0300,
    );
    
    // Navigate to active trip with complete data
    context.push(
      '/active-trip',
      extra: {
        'rideId': offer['rideId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'driverName': offer['name'] ?? 'Driver',
        'driverPhone': '+92300123456', // TODO: Get from offer
        'vehicleInfo': '${offer['vehicleModel']} - ${offer['vehicleNumber']}',
        'fare': offer['price']?.toString() ?? '250',
        'distance': _rideData?['actualDistance']?.toString() ?? '5.5 km',
        'duration': _rideData?['actualDuration']?.toString() ?? '15 min',
        'pickupLat': _rideData?['pickupLat'] ?? 24.8607,
        'pickupLng': _rideData?['pickupLng'] ?? 67.0011,
        'destinationLat': _rideData?['destLat'] ?? 24.8138,
        'destinationLng': _rideData?['destLng'] ?? 67.0300,
        'pickup': _rideData?['pickup'] ?? 'Current Location',
        'destination': _rideData?['destination'] ?? 'Destination',
        'driverId': offer['driverId'],
        'customerId': 'customer_123',
      },
    );
  }
  
  void _makeCounterOffer(Map<String, dynamic> offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CounterOfferSheet(
        originalOffer: offer,
        onCounterOffer: (newPrice) {
          setState(() {
            // Update the offer with counter-offer
            final index = _driverOffers.indexWhere((o) => o['id'] == offer['id']);
            if (index != -1) {
              _driverOffers[index] = {
                ...offer,
                'price': newPrice,
                'isCounterOffer': true,
                'originalPrice': offer['price'],
              };
            }
          });
          
          // Simulate driver response after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              final accepted = math.Random().nextBool();
              if (accepted) {
                _acceptDriverOffer(_driverOffers.firstWhere((o) => o['id'] == offer['id']));
              } else {
                setState(() {
                  _driverOffers.removeWhere((o) => o['id'] == offer['id']);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Driver declined your counter-offer'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          });
        },
      ),
    );
  }
  
  void _showNoDriversDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Drivers Available'),
        content: const Text('No drivers accepted your ride request. Would you like to try again with a higher fare?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _driverOffers.clear();
                _remainingSeconds = 30;
                _isSearching = true;
              });
              _startCountdown();
              _simulateDriverOffers();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _offerTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Ride?'),
            content: const Text('Are you sure you want to cancel finding drivers?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Driver Offers'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds > 10 ? Colors.blue[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: _remainingSeconds > 10 ? Colors.blue : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_remainingSeconds}s',
                    style: TextStyle(
                      color: _remainingSeconds > 10 ? Colors.blue : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Ride summary
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_rideData?['vehicleType'] ?? 'Economy'} • ${_rideData?['distance']?.toStringAsFixed(1) ?? '0'} km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimated Fare: PKR ${_rideData?['estimatedFare'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_driverOffers.length} offers',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Driver offers or searching animation
            Expanded(
              child: _isSearching
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.search,
                                    size: 50,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Finding drivers near you...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Drivers can offer their best price',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _driverOffers.length,
                      itemBuilder: (context, index) {
                        final offer = _driverOffers[index];
                        final isCounterOffer = offer['isCounterOffer'] ?? false;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Driver avatar
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey[300],
                                      child: Icon(
                                        Icons.person,
                                        size: 30,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Driver info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                offer['name'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber[50],
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.star,
                                                      size: 12,
                                                      color: Colors.amber[700],
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      offer['rating'].toStringAsFixed(1),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.amber[700],
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${offer['vehicleModel']} • ${offer['vehicleNumber']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 12,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${offer['arrivalTime']} min away',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.local_taxi,
                                                size: 12,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${offer['trips']} trips',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Price
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (isCounterOffer) ...[
                                          Text(
                                            'PKR ${offer['originalPrice']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          'PKR ${offer['price']}',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isCounterOffer ? Colors.orange : Colors.black,
                                          ),
                                        ),
                                        if (isCounterOffer)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[50],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Negotiating',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Action buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: isCounterOffer ? null : () => _makeCounterOffer(offer),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                          side: BorderSide(
                                            color: isCounterOffer ? Colors.grey[300]! : Colors.orange,
                                          ),
                                        ),
                                        child: Text(
                                          isCounterOffer ? 'Waiting...' : 'Counter Offer',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _acceptDriverOffer(offer),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).primaryColor,
                                        ),
                                        child: const Text(
                                          'Accept',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Counter offer bottom sheet
class _CounterOfferSheet extends StatefulWidget {
  final Map<String, dynamic> originalOffer;
  final Function(int) onCounterOffer;
  
  const _CounterOfferSheet({
    required this.originalOffer,
    required this.onCounterOffer,
  });
  
  @override
  State<_CounterOfferSheet> createState() => _CounterOfferSheetState();
}

class _CounterOfferSheetState extends State<_CounterOfferSheet> {
  late TextEditingController _priceController;
  late int _suggestedPrice;
  
  @override
  void initState() {
    super.initState();
    _suggestedPrice = (widget.originalOffer['price'] * 0.9).round();
    _priceController = TextEditingController(text: _suggestedPrice.toString());
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const Text(
                'Make Counter Offer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Driver\'s offer: PKR ${widget.originalOffer['price']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              
              // Price input
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Your offer',
                  prefixText: 'PKR ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 12),
              
              // Quick price buttons
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickPriceChip((widget.originalOffer['price'] * 0.8).round()),
                  _buildQuickPriceChip((widget.originalOffer['price'] * 0.85).round()),
                  _buildQuickPriceChip((widget.originalOffer['price'] * 0.9).round()),
                  _buildQuickPriceChip((widget.originalOffer['price'] * 0.95).round()),
                ],
              ),
              const SizedBox(height: 20),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final price = int.tryParse(_priceController.text);
                        if (price != null && price > 0) {
                          Navigator.of(context).pop();
                          widget.onCounterOffer(price);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text(
                        'Send Offer',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickPriceChip(int price) {
    return ActionChip(
      label: Text('PKR $price'),
      onPressed: () {
        _priceController.text = price.toString();
      },
      backgroundColor: Colors.grey[100],
    );
  }
}