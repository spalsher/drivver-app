import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider;
import '../../../../core/providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  String _selectedCountryCode = '+92'; // Pakistan
  
  final List<Map<String, String>> _countryCodes = [
    {'code': '+92', 'name': 'Pakistan', 'flag': '🇵🇰'},
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'name': 'USA', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧'},
  ];

  Future<void> _sendOtp() async {
    if (_phoneController.text.length < 10) {
      _showError('Please enter a valid phone number');
      return;
    }

    final authProvider = provider.Provider.of<AuthProvider>(context, listen: false);
    final fullPhone = '$_selectedCountryCode${_phoneController.text}';

    try {
      final result = await authProvider.sendOtp(fullPhone);
      
      if (result['success']) {
        setState(() {
          _isOtpSent = true;
        });
        
        _showSuccess(result['message'] ?? 'OTP sent successfully');
        
        // Show development OTP if available
        final otp = result['otp'];
        if (otp != null) {
          _showDevelopmentOtp(otp);
        }
      } else {
        _showError(result['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      _showError('Failed to send OTP. Please try again.');
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      _showError('Please enter the 6-digit OTP');
      return;
    }

    final authProvider = provider.Provider.of<AuthProvider>(context, listen: false);
    final fullPhone = '$_selectedCountryCode${_phoneController.text}';

    try {
      final success = await authProvider.verifyOtp(fullPhone, _otpController.text);
      
      if (success) {
        // Navigate to verification screen for driver documents
        context.go('/verification');
      } else {
        _showError(authProvider.errorMessage ?? 'Invalid OTP. Please try again.');
      }
    } catch (e) {
      _showError('Failed to verify OTP. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showDevelopmentOtp(String otp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Development OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your OTP is: $otp'),
            const SizedBox(height: 16),
            const Text(
              'This is for development only',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _otpController.text = otp;
            },
            child: const Text('Auto-fill'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return provider.Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isLoading = authProvider.isLoading;
        
        return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isOtpSent ? 'Verify OTP' : 'Driver Sign In'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // Header
            Text(
              _isOtpSent 
                  ? 'Enter verification code'
                  : 'Welcome back, Driver!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isOtpSent
                  ? 'We sent a code to $_selectedCountryCode ${_phoneController.text}'
                  : 'Sign in to start earning with Drivrr',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            
            if (!_isOtpSent) ...[
              // Phone number input
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Country code dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountryCode,
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryCode = value!;
                          });
                        },
                        items: _countryCodes.map((country) {
                          return DropdownMenuItem(
                            value: country['code'],
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  country['flag']!,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(country['code']!),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Enter phone number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Send OTP button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _sendOtp,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Send OTP'),
                ),
              ),
            ] else ...[
              // OTP input
              const Text(
                'Verification Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter 6-digit code',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    _verifyOtp();
                  }
                },
              ),
              const SizedBox(height: 24),
              
              // Verify OTP button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _verifyOtp,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify & Continue'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Resend OTP
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isOtpSent = false;
                      _otpController.clear();
                    });
                  },
                  child: const Text('Resend OTP'),
                ),
              ),
            ],
            
            const SizedBox(height: 40),
            
            // Driver benefits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Why drive with Drivrr?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitRow(Icons.trending_up, 'Higher earnings with fare negotiation'),
                  _buildBenefitRow(Icons.schedule, 'Complete schedule flexibility'),
                  _buildBenefitRow(Icons.security, '24/7 safety support'),
                  _buildBenefitRow(Icons.payment, 'Instant daily payouts'),
                ],
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }
  
  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
