import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final List<TripHistory> _trips = [
    TripHistory(
      id: '1',
      driverName: 'Ahmed Khan',
      vehicleInfo: 'White Toyota Corolla',
      pickupAddress: 'DHA Phase 2, Karachi',
      destinationAddress: 'Clifton Beach, Karachi',
      fare: 280,
      rating: 5,
      date: DateTime.now().subtract(const Duration(hours: 2)),
      status: TripStatus.completed,
    ),
    TripHistory(
      id: '2',
      driverName: 'Muhammad Ali',
      vehicleInfo: 'Silver Honda Civic',
      pickupAddress: 'Gulshan-e-Iqbal, Karachi',
      destinationAddress: 'Dolmen Mall, Karachi',
      fare: 320,
      rating: 4,
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: TripStatus.completed,
    ),
    TripHistory(
      id: '3',
      driverName: 'Hassan Sheikh',
      vehicleInfo: 'Blue Suzuki Alto',
      pickupAddress: 'Saddar, Karachi',
      destinationAddress: 'Karachi Airport',
      fare: 450,
      rating: 0, // Not rated
      date: DateTime.now().subtract(const Duration(days: 3)),
      status: TripStatus.cancelled,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Trip History',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: _trips.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _trips.length,
              itemBuilder: (context, index) {
                final trip = _trips[index];
                return _buildTripCard(trip, theme);
              },
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Trips Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed trips will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Book Your First Ride'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(TripHistory trip, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(trip.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trip.status.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trip.status.displayName,
                    style: TextStyle(
                      color: trip.status.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Trip Route
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.grey[300],
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5722),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.pickupAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        trip.destinationAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Driver and Fare Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.driverName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      trip.vehicleInfo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PKR ${trip.fare}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                    if (trip.rating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[600],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            trip.rating.toString(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            
            // Action Buttons for specific statuses
            if (trip.status == TripStatus.completed && trip.rating == 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.push('/trip/rating', extra: {
                      'driver': {
                        'driverName': trip.driverName,
                        'rating': 4.8,
                        'totalTrips': 200,
                        'vehicleColor': 'White',
                        'vehicleMake': 'Toyota',
                        'vehicleModel': 'Corolla',
                      },
                      'finalFare': trip.fare,
                    });
                  },
                  child: const Text('Rate This Trip'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class TripHistory {
  final String id;
  final String driverName;
  final String vehicleInfo;
  final String pickupAddress;
  final String destinationAddress;
  final int fare;
  final int rating;
  final DateTime date;
  final TripStatus status;

  TripHistory({
    required this.id,
    required this.driverName,
    required this.vehicleInfo,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.rating,
    required this.date,
    required this.status,
  });
}

enum TripStatus {
  completed,
  cancelled,
  active,
}

extension TripStatusExtension on TripStatus {
  String get displayName {
    switch (this) {
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
      case TripStatus.active:
        return 'Active';
    }
  }

  Color get color {
    switch (this) {
      case TripStatus.completed:
        return Colors.green;
      case TripStatus.cancelled:
        return Colors.red;
      case TripStatus.active:
        return Colors.blue;
    }
  }
}
