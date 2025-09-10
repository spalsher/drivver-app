import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isOtpSent = false;
  String _selectedCountryCode = '+92'; // Default to Pakistan

  void _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authNotifier = ref.read(authProvider.notifier);
      final fullPhone = '$_selectedCountryCode${_phoneController.text}';
      final result = await authNotifier.sendOtp(fullPhone);

      setState(() {
        _isLoading = false;
      });

      if (result != null) {
        setState(() {
          _isOtpSent = true;
        });
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'OTP sent to $fullPhone'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Show OTP in development mode
          final otp = result['otp'];
          if (otp != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => AlertDialog(
                    title: const Text('🔒 Development OTP'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('For testing purposes only:'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            otp,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap to copy or dismiss',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          _otpController.text = otp;
                          Navigator.pop(context);
                        },
                        child: const Text('Auto-fill'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            });
          }
        }
      } else {
        final error = ref.read(authProvider).error;
        if (mounted && error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _verifyOTP() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authNotifier = ref.read(authProvider.notifier);
    final fullPhone = '$_selectedCountryCode${_phoneController.text}';
    final success = await authNotifier.verifyOtp(fullPhone, _otpController.text);
    
    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        // Mark onboarding as completed for persistent authentication
        const storage = FlutterSecureStorage();
        await storage.write(key: 'onboarding_completed', value: 'true');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful! Welcome to Drivrr'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        print('✅ Authentication successful - marked onboarding as completed');
        
        // Navigate to home screen
        context.go('/home');
      }
    } else {
      final error = ref.read(authProvider).error;
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Header
              Text(
                'Welcome to Drivrr',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Enter your phone number to get started',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // Phone input form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isOtpSent) ...[
                      // Phone Number Input
                      Text(
                        'Phone Number',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Country Code Selector
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[50],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                items: const [
                                  DropdownMenuItem(value: '+92', child: Text('🇵🇰 +92')),
                                  DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                                  DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                                  DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCountryCode = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Phone Number Input
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: '300 1234567',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                if (value.length < 10) {
                                  return 'Please enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // OTP Verification
                      Text(
                        'Enter OTP',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a code to $_selectedCountryCode${_phoneController.text}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          prefixIcon: Icon(Icons.security),
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Resend OTP
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isOtpSent = false;
                            _otpController.clear();
                          });
                        },
                        child: const Text('Resend OTP'),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_isOtpSent ? _verifyOTP : _sendOTP),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(_isOtpSent ? 'Verify OTP' : 'Send OTP'),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Terms and conditions
              Text.rich(
                TextSpan(
                  text: 'By continuing, you agree to our ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
              
              // Social login options (future enhancement)
              Text(
                'or continue with',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement Google Sign In
                      },
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('Google'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement Apple Sign In
                      },
                      icon: const Icon(Icons.apple),
                      label: const Text('Apple'),
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}

