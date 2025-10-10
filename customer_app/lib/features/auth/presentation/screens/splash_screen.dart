import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _textAnimationController;
  late AnimationController _loadingAnimationController;
  
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _logoSlideAnimation;
  
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  
  late Animation<double> _loadingFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
    _navigateToNext();
  }

  void _initializeAnimations() {
    // Logo animations (600ms duration)
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOut,
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Text animations (400ms duration, starts after logo)
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeOut,
    ));

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Loading animation (300ms duration, starts after text)
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _loadingFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.easeOut,
    ));
  }

  void _startAnimationSequence() async {
    // Haptic feedback for app launch
    HapticFeedback.lightImpact();
    
    // Start logo animation immediately
    _logoAnimationController.forward();
    
    // Start text animation after 300ms
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _textAnimationController.forward();
    }
    
    // Start loading animation after another 200ms
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _loadingAnimationController.forward();
    }
  }

  void _navigateToNext() {
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (mounted) {
        await _checkAuthenticationStatus();
      }
    });
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      const storage = FlutterSecureStorage();
      
      // Check if user has stored auth token
      final authToken = await storage.read(key: 'auth_token');
      final hasCompletedOnboarding = await storage.read(key: 'onboarding_completed');
      
      print('🔐 Checking authentication...');
      print('🔑 Auth token exists: ${authToken != null}');
      print('📚 Onboarding completed: ${hasCompletedOnboarding == 'true'}');
      
      if (authToken != null && authToken.isNotEmpty) {
        // User is logged in, check if onboarding is completed
        if (hasCompletedOnboarding == 'true') {
          print('✅ User authenticated and onboarded - going to home');
          context.go('/home');
        } else {
          print('📚 User authenticated but needs onboarding');
          context.go('/onboarding');
        }
      } else {
        // User is not logged in, go to onboarding
        print('❌ User not authenticated - going to onboarding');
        context.go('/onboarding');
      }
    } catch (e) {
      print('❌ Error checking authentication: $e');
      // On error, go to onboarding as fallback
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _textAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            // Simple solid background - common in ride-hailing apps
            color: Color(0xFFFFFFFF), // White background
          ),
          child: Column(
            children: [
              // Top spacer - matches sample proportions
              const Spacer(flex: 3),
              
              // Logo Section - centered and prominent
              AnimatedBuilder(
                animation: _logoAnimationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _logoFadeAnimation,
                    child: SlideTransition(
                      position: _logoSlideAnimation,
                      child: ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_taxi,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // Text Section - matches sample spacing
              AnimatedBuilder(
                animation: _textAnimationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textFadeAnimation,
                    child: SlideTransition(
                      position: _textSlideAnimation,
                      child: Column(
                        children: [
                          // App Name - clean and professional
                          Text(
                            AppConstants.appName,
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: const Color(0xFF2196F3),
                              fontWeight: FontWeight.bold,
                              fontSize: 36,
                              letterSpacing: -0.5,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Tagline - subtle and clean
                          Text(
                            'Set your price. Choose your ride.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              // Middle spacer - matches sample proportions  
              const Spacer(flex: 4),
              
              // Loading Section - positioned like in sample
              AnimatedBuilder(
                animation: _loadingAnimationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _loadingFadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Column(
                        children: [
                          // Loading indicator - clean
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                              strokeWidth: 2.5,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Loading text - clean
                          Text(
                            'Loading...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

