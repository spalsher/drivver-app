import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/ride_booking_screen.dart';
import '../../features/booking/presentation/screens/location_search_screen.dart';
import '../../features/booking/presentation/screens/route_preview_screen.dart';
import '../../features/haggling/presentation/screens/haggling_screen.dart';
import '../../features/trip/presentation/screens/trip_screen.dart';
import '../../features/trip/presentation/screens/active_trip_screen.dart';
import '../../features/trip/presentation/screens/trip_rating_screen.dart';
import '../../features/trip/presentation/screens/trip_history_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

class NavigationService {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Splash and Authentication Routes
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      
      // Main App Routes
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/booking',
        name: 'booking',
        builder: (context, state) => const BookingScreen(),
      ),
      GoRoute(
        path: '/ride-booking',
        name: 'ride-booking',
        builder: (context, state) => const RideBookingScreen(),
      ),
      GoRoute(
        path: '/location-search',
        name: 'location-search',
        builder: (context, state) => const LocationSearchScreen(),
      ),
      GoRoute(
        path: '/route-preview',
        name: 'route-preview',
        builder: (context, state) => const RoutePreviewScreen(),
      ),
      GoRoute(
        path: '/haggling',
        name: 'haggling',
        builder: (context, state) => const HagglingScreen(),
      ),
      GoRoute(
        path: '/active-trip',
        name: 'active-trip',
        builder: (context, state) {
          final rideData = state.extra as Map<String, dynamic>;
          return ActiveTripScreen(
            rideId: rideData['rideId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            rideDetails: rideData,
          );
        },
      ),
      GoRoute(
        path: '/trip/rating',
        name: 'trip-rating',
        builder: (context, state) {
          final tripData = state.extra as Map<String, dynamic>;
          return TripRatingScreen(tripData: tripData);
        },
      ),
      GoRoute(
        path: '/trip/history',
        name: 'trip-history',
        builder: (context, state) => const TripHistoryScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId',
        name: 'trip',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          return TripScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    
    // Error handling
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

