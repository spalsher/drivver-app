import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/document_verification_service.dart';
import '../../../../core/constants/app_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final docService = Provider.of<DocumentVerificationService>(context, listen: false);
      
      debugPrint('🔄 Profile screen: Loading driver profile and verification status...');
      
      // Load document verification status first (this works for all users)
      await docService.loadDocumentStatus();
      
      // Try to load driver profile (may fail for new users)
      try {
        await authProvider.loadDriverProfile();
        debugPrint('✅ Profile screen: Driver profile loaded');
      } catch (e) {
        debugPrint('ℹ️ Profile screen: Driver profile not found (new user): $e');
        // This is normal for new users who haven't completed driver registration
      }
      
      debugPrint('✅ Profile screen: Data loading completed');
    } catch (e) {
      debugPrint('❌ Profile screen: Error loading data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(AppConstants.primaryColorValue),
              ),
            );
          }

          final driverData = authProvider.driverData;
          
          return RefreshIndicator(
            onRefresh: _loadDriverProfile,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, driverData),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildProfileCard(driverData),
                        const SizedBox(height: 16),
                        _buildVehicleCard(driverData),
                        const SizedBox(height: 16),
                        _buildStatsCard(driverData),
                        const SizedBox(height: 16),
                        _buildMenuSection(context),
                        const SizedBox(height: 16),
                        _buildLogoutButton(context, authProvider),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Map<String, dynamic>? driverData) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: const Color(AppConstants.primaryColorValue),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          driverData != null 
              ? '${driverData['first_name'] ?? 'Driver'} ${driverData['last_name'] ?? ''}'.trim()
              : 'Driver Profile',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(AppConstants.primaryColorValue),
                Color(AppConstants.secondaryColorValue),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage: driverData?['profile_picture_url'] != null
                      ? NetworkImage(driverData!['profile_picture_url'])
                      : null,
                  child: driverData?['profile_picture_url'] == null
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: Color(AppConstants.primaryColorValue),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Consumer<DocumentVerificationService>(
                  builder: (context, docService, child) {
                    final approvedCount = docService.approvedDocumentsCount;
                    final totalCount = docService.totalDocumentsCount;
                    final isFullyVerified = docService.isAllDocumentsApproved;
                    
                    if (isFullyVerified) {
                      return const Text(
                        '✅ Verified Driver',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    } else if (approvedCount > 0) {
                      return Text(
                        '📋 $approvedCount/$totalCount Documents Verified',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    } else {
                      return const Text(
                        '⏳ Pending Verification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: () => _showEditProfileDialog(context),
        ),
      ],
    );
  }

  Widget _buildProfileCard(Map<String, dynamic>? driverData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Color(AppConstants.primaryColorValue),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Phone Number', driverData?['phone'] ?? 'Not provided'),
            _buildInfoRow('Email', driverData?['email'] ?? 'Not provided'),
            _buildInfoRow('Joined', driverData?['created_at'] != null 
                ? _formatDate(driverData!['created_at'])
                : 'Unknown'),
            _buildInfoRow('License Number', driverData?['license_number'] ?? 'Not provided'),
            _buildInfoRow('License Expiry', driverData?['license_expiry'] != null
                ? _formatDate(driverData!['license_expiry'])
                : 'Not provided'),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic>? driverData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  color: Color(AppConstants.primaryColorValue),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Vehicle Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Make & Model', 
                '${driverData?['vehicle_make'] ?? 'Unknown'} ${driverData?['vehicle_model'] ?? ''}'),
            _buildInfoRow('Year', driverData?['vehicle_year']?.toString() ?? 'Unknown'),
            _buildInfoRow('Color', driverData?['vehicle_color'] ?? 'Unknown'),
            _buildInfoRow('Plate Number', driverData?['plate_number'] ?? 'Unknown'),
            _buildInfoRow('Type', driverData?['vehicle_type'] ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic>? driverData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: Color(AppConstants.primaryColorValue),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Driver Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Trips',
                    driverData?['total_trips']?.toString() ?? '0',
                    Icons.local_taxi,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Rating',
                    '${driverData?['rating']?.toStringAsFixed(1) ?? '5.0'} ⭐',
                    Icons.star,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Earnings',
                    'PKR ${driverData?['total_earnings']?.toStringAsFixed(0) ?? '0'}',
                    Icons.account_balance_wallet,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Commission Rate',
                    '${driverData?['commission_rate']?.toStringAsFixed(1) ?? '15.0'}%',
                    Icons.percent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(AppConstants.primaryColorValue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(AppConstants.primaryColorValue),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(AppConstants.primaryColorValue),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        _buildMenuCard([
          _buildMenuItem(
            'Document Verification',
            'Manage your documents',
            Icons.verified_user,
            () => context.push('/verification'),
          ),
          _buildMenuItem(
            'Earnings & Payments',
            'View earnings and withdraw',
            Icons.account_balance_wallet,
            () => _showComingSoon(context, 'Earnings'),
          ),
          _buildMenuItem(
            'Trip History',
            'View your completed trips',
            Icons.history,
            () => _showComingSoon(context, 'Trip History'),
          ),
        ]),
        const SizedBox(height: 12),
        _buildMenuCard([
          _buildMenuItem(
            'Settings',
            'App preferences and notifications',
            Icons.settings,
            () => _showComingSoon(context, 'Settings'),
          ),
          _buildMenuItem(
            'Help & Support',
            'Get help and contact support',
            Icons.help_outline,
            () => _showComingSoon(context, 'Help & Support'),
          ),
          _buildMenuItem(
            'About',
            'App version and information',
            Icons.info_outline,
            () => _showAboutDialog(context),
          ),
        ]),
      ],
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(AppConstants.primaryColorValue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(AppConstants.primaryColorValue),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutDialog(context, authProvider),
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: const Text('Profile editing functionality will be implemented soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: const Color(AppConstants.primaryColorValue),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Drivrr Driver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: ${AppConstants.appVersion}'),
            const SizedBox(height: 8),
            const Text('Drivrr Driver App - Your reliable ride-hailing partner'),
            const SizedBox(height: 8),
            const Text('Features:'),
            const Text('• Real-time ride requests'),
            const Text('• Fare negotiation'),
            const Text('• Document verification'),
            const Text('• Earnings tracking'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logout();
              if (context.mounted) {
                context.go('/auth');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}