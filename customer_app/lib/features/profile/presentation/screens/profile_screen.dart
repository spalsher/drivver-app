import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/providers/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await UserService.getUserProfile();
      setState(() {
        _userProfile = profile?['user'];
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Profile',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profile',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              _showEditProfileDialog();
            },
            icon: const Icon(Icons.edit, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue[100],
                    backgroundImage: _userProfile?['profile_photo'] != null 
                        ? NetworkImage(_userProfile!['profile_photo']) 
                        : null,
                    child: _userProfile?['profile_photo'] == null 
                        ? Text(
                            (_userProfile?['first_name']?.substring(0, 1)?.toUpperCase() ?? 'U'),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_userProfile?['first_name'] ?? 'User'} ${_userProfile?['last_name'] ?? 'Name'}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userProfile?['phone'] ?? '+92 300 0000000',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star,
                        size: 20,
                        color: Colors.amber[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_userProfile?['stats']?['averageRating']?.toStringAsFixed(1) ?? '0.0'} • ${_userProfile?['stats']?['totalTrips'] ?? 0} trips',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quick Stats
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('23', 'Total Trips', Icons.local_taxi),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildStatItem('PKR 6,840', 'Total Spent', Icons.attach_money),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildStatItem('4.8', 'Rating', Icons.star),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Menu Items
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.person,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    onTap: () {
                      // TODO: Navigate to edit profile
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.payment,
                    title: 'Payment Methods',
                    subtitle: 'Manage your payment options',
                    onTap: () {
                      // TODO: Navigate to payment methods
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.location_on,
                    title: 'Saved Places',
                    subtitle: 'Home, Work, and other favorites',
                    onTap: () {
                      // TODO: Navigate to saved places
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.share,
                    title: 'Refer Friends',
                    subtitle: 'Invite friends and earn rewards',
                    onTap: () {
                      // TODO: Navigate to referral
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    subtitle: 'Get help with your account',
                    onTap: () {
                      // TODO: Navigate to help
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.info,
                    title: 'About',
                    subtitle: 'App version and legal information',
                    onTap: () {
                      // TODO: Navigate to about
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    onTap: _handleLogout,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Logout Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            context.pop(); // Close dialog
                            context.go('/auth'); // Go to auth
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2196F3), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2196F3),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2196F3),
              size: 20,
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
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.grey[200],
            indent: 16,
            endIndent: 16,
          ),
      ],
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

  void _showEditProfileDialog() {
    final firstNameController = TextEditingController(text: _userProfile?['first_name'] ?? '');
    final lastNameController = TextEditingController(text: _userProfile?['last_name'] ?? '');
    final homeAddressController = TextEditingController(text: _userProfile?['home_address'] ?? '');
    final workAddressController = TextEditingController(text: _userProfile?['work_address'] ?? '');
    String selectedGender = _userProfile?['gender'] ?? 'male';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Gender Selection
              const Text('Gender', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = 'male'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedGender == 'male' ? Colors.blue.shade50 : Colors.grey.shade100,
                          border: Border.all(
                            color: selectedGender == 'male' ? Colors.blue : Colors.grey.shade300,
                            width: selectedGender == 'male' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.male,
                              color: selectedGender == 'male' ? Colors.blue : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Male',
                              style: TextStyle(
                                color: selectedGender == 'male' ? Colors.blue : Colors.grey,
                                fontWeight: selectedGender == 'male' ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedGender = 'female'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedGender == 'female' ? Colors.pink.shade50 : Colors.grey.shade100,
                          border: Border.all(
                            color: selectedGender == 'female' ? Colors.pink : Colors.grey.shade300,
                            width: selectedGender == 'female' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.female,
                              color: selectedGender == 'female' ? Colors.pink : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Female',
                              style: TextStyle(
                                color: selectedGender == 'female' ? Colors.pink : Colors.grey,
                                fontWeight: selectedGender == 'female' ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Safety features info for female users
              if (selectedGender == 'female') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.pink.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.pink.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Enhanced Safety Features',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.pink.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Priority access to top-rated drivers (4.8+ rating)\n• Enhanced safety monitoring during rides\n• Feminine theme with soft colors\n• Additional safety notifications',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              TextField(
                controller: homeAddressController,
                decoration: const InputDecoration(
                  labelText: 'Home Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: workAddressController,
                decoration: const InputDecoration(
                  labelText: 'Work Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _updateProfile(
                firstName: firstNameController.text.trim(),
                lastName: lastNameController.text.trim(),
                homeAddress: homeAddressController.text.trim(),
                workAddress: workAddressController.text.trim(),
                gender: selectedGender,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        // Clear all authentication data
        final apiService = ApiService();
        await apiService.clearAuthData();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to onboarding
        context.go('/onboarding');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProfile({
    required String firstName,
    required String lastName,
    required String homeAddress,
    required String workAddress,
    required String gender,
  }) async {
    try {
      final result = await UserService.updateUserProfile(
        firstName: firstName.isNotEmpty ? firstName : null,
        lastName: lastName.isNotEmpty ? lastName : null,
        homeAddress: homeAddress.isNotEmpty ? homeAddress : null,
        workAddress: workAddress.isNotEmpty ? workAddress : null,
        gender: gender,
        safetyPreferences: gender == 'female' ? {
          'topRatedDriversOnly': true,
          'enhancedMonitoring': true,
          'safetyNotifications': true,
        } : null,
        themePreference: gender == 'female' ? 'feminine' : 'default',
      );

      if (result != null) {
        setState(() {
          _userProfile = result['user'];
        });
        
        // Update theme based on new gender
        ref.read(themeProvider.notifier).updateTheme(
          result['user']['gender'],
          result['user']['theme_preference'],
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gender == 'female' 
                ? '✅ Profile updated! Welcome to your feminine theme 💕'
                : '✅ Profile updated successfully'
            ),
            backgroundColor: gender == 'female' ? Colors.pink : Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error updating profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}