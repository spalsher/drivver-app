import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../core/services/native_websocket_service.dart';
import '../../../home/presentation/widgets/flutter_map_widget.dart';

class ActiveTripScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideDetails;

  const ActiveTripScreen({
    super.key,
    required this.rideId,
    required this.rideDetails,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  // Trip tracking state
  String _tripStatus = 'accepted'; // accepted, pickup, in_transit, completed
  LatLng? _driverLocation;
  String _estimatedArrival = 'Calculating...';
  String _driverName = '';
  String _driverPhone = '';
  String _vehicleInfo = '';
  double _tripProgress = 0.0;
  
  // Driver info
  Map<String, dynamic>? _driverInfo;
  
  // Subscriptions
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _tripStatusSubscription;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    // Start pulse animation
    _pulseController.repeat(reverse: true);
    
    // Initialize trip tracking
    _initializeTripTracking();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _driverLocationSubscription?.cancel();
    _tripStatusSubscription?.cancel();
    super.dispose();
  }

  void _initializeTripTracking() {
    print('🚗 Initializing trip tracking for ride: ${widget.rideId}');
    
    // Extract initial ride details
    _driverName = widget.rideDetails['driverName'] ?? 'Driver';
    _driverPhone = widget.rideDetails['driverPhone'] ?? '';
    _vehicleInfo = widget.rideDetails['vehicleInfo'] ?? 'Vehicle';
    
    // Connect to WebSocket for real-time updates
    _connectToTripTracking();
  }

  void _connectToTripTracking() {
    print('🌐 Connecting to trip tracking WebSocket...');
    
    // Listen for driver location updates and ride updates from Go backend
    _driverLocationSubscription = NativeWebSocketService.instance.rideUpdates.listen(
      (update) {
        print('📍 Active trip update: $update');
        
        if (update['rideId'] == widget.rideId || update['type'] == 'driver_location_update') {
          if (update['type'] == 'driver_location_update') {
            setState(() {
              _driverLocation = LatLng(
                (update['latitude'] as num?)?.toDouble() ?? 0.0,
                (update['longitude'] as num?)?.toDouble() ?? 0.0,
              );
              _estimatedArrival = '${update['eta'] ?? 'Unknown'} min';
            });
            print('📍 Driver location updated: $_driverLocation, ETA: $_estimatedArrival');
          } else if (update['type'] == 'driver_assigned') {
            setState(() {
              _driverLocation = LatLng(
                (update['driverLat'] as num?)?.toDouble() ?? 0.0,
                (update['driverLng'] as num?)?.toDouble() ?? 0.0,
              );
              _estimatedArrival = '${update['driverETA'] ?? 'Unknown'} min';
              _driverName = update['driverName'] ?? 'Driver';
            });
            print('🚗 Driver assigned: $_driverName, ETA: $_estimatedArrival');
          } else if (update['type'] == 'ride_completed') {
            setState(() {
              _tripStatus = 'completed';
              _tripProgress = 1.0;
            });
            print('🏁 Ride completed!');
          }
        }
      },
      onError: (error) {
        print('❌ Trip tracking error: $error');
      },
    );
          _progressController.animateTo(_tripProgress);
          
          // Handle trip completion
          if (_tripStatus == 'completed') {
            _handleTripCompletion();
          }
        }
      },
      onError: (error) {
        print('❌ Trip status stream error: $error');
      },
    );

    // Request initial driver location
    WebSocketService.instance.requestDriverLocation(widget.rideId);
  }

  void _handleTripCompletion() {
    print('🏁 Trip completed!');
    
    // Show completion dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildTripCompletionDialog(),
    );
  }

  Widget _buildTripCompletionDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 30),
          SizedBox(width: 12),
          Text('Trip Completed!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your ride with $_driverName has been completed successfully.'),
          const SizedBox(height: 16),
          const Text('Rate your experience:'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => 
              IconButton(
                onPressed: () {
                  // TODO: Submit rating
                },
                icon: Icon(
                  Icons.star,
                  color: index < 4 ? Colors.amber : Colors.grey[300],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/home');
          },
          child: const Text('Done'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with driver tracking
          FlutterMapWidget(
            pickupLocation: LatLng(
              widget.rideDetails['pickupLat']?.toDouble() ?? 0.0,
              widget.rideDetails['pickupLng']?.toDouble() ?? 0.0,
            ),
            destinationLocation: LatLng(
              widget.rideDetails['destinationLat']?.toDouble() ?? 0.0,
              widget.rideDetails['destinationLng']?.toDouble() ?? 0.0,
            ),
            driverLocation: _driverLocation, // New parameter for driver tracking
          ),
          
          // Trip Status Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 8),
                        blurRadius: 32,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Back button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () => context.pop(),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getTripStatusText(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black.withOpacity(0.8),
                                    ),
                                  ),
                                  Text(
                                    'ETA: $_estimatedArrival',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Trip progress indicator
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress bar
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _progressAnimation.value,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 6,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Driver Info Card
          if (_driverInfo != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 180,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          offset: const Offset(0, 4),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Driver avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driverName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black.withOpacity(0.8),
                                  ),
                                ),
                                Text(
                                  _vehicleInfo,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Call button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () {
                                // TODO: Implement call driver
                                print('📞 Calling driver: $_driverPhone');
                              },
                              icon: const Icon(
                                Icons.phone,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Trip Actions
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(0, -8),
                        blurRadius: 32,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Trip details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Distance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  widget.rideDetails['distance'] ?? '0 km',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Fare',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  'Rs. ${widget.rideDetails['fare'] ?? '0'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Duration',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  widget.rideDetails['duration'] ?? '0 min',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Action buttons based on trip status
                        if (_tripStatus == 'accepted' || _tripStatus == 'pickup') ...[
                          _buildGlassButton(
                            context: context,
                            onPressed: _cancelTrip,
                            icon: Icons.cancel_outlined,
                            label: 'Cancel Trip',
                            isPrimary: false,
                            isDestructive: true,
                          ),
                        ] else if (_tripStatus == 'in_transit') ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildGlassButton(
                                  context: context,
                                  onPressed: () {
                                    // TODO: Share trip details
                                  },
                                  icon: Icons.share,
                                  label: 'Share Trip',
                                  isPrimary: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGlassButton(
                                  context: context,
                                  onPressed: () {
                                    // TODO: Emergency contact
                                  },
                                  icon: Icons.emergency,
                                  label: 'Emergency',
                                  isPrimary: false,
                                  isDestructive: true,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  String _getTripStatusText() {
    switch (_tripStatus) {
      case 'accepted':
        return 'Driver Accepted';
      case 'pickup':
        return 'Driver Arriving';
      case 'in_transit':
        return 'On the Way';
      case 'completed':
        return 'Trip Completed';
      default:
        return 'Trip Active';
    }
  }

  Color _getStatusColor() {
    switch (_tripStatus) {
      case 'accepted':
        return Colors.blue;
      case 'pickup':
        return Colors.orange;
      case 'in_transit':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      default:
        return AppTheme.primaryColor;
    }
  }

  void _cancelTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Trip'),
        content: const Text('Are you sure you want to cancel this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              WebSocketService.instance.cancelTrip(widget.rideId);
              context.go('/home');
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
    bool isDestructive = false,
  }) {
    final buttonColor = isDestructive 
        ? Colors.red 
        : isPrimary 
            ? AppTheme.primaryColor 
            : AppTheme.primaryColor;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: buttonColor.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        buttonColor,
                        buttonColor.withOpacity(0.8),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPrimary 
                    ? Colors.white.withOpacity(0.3)
                    : buttonColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withOpacity(isPrimary ? 0.3 : 0.1),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isPrimary 
                      ? Colors.white
                      : buttonColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPrimary 
                        ? Colors.white
                        : buttonColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}