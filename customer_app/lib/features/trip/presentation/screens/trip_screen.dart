import 'package:flutter/material.dart';

class TripScreen extends StatelessWidget {
  final String tripId;
  
  const TripScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Trip Screen - Trip ID: $tripId'),
      ),
    );
  }
}

