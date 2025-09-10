import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

// Auth state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
    );
  }
}

// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;

  AuthNotifier(this._apiService) : super(const AuthState()) {
    _initializeAuth();
  }

  // Initialize auth state from stored data
  Future<void> _initializeAuth() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final token = await _apiService.getAuthToken();
      final userData = await _apiService.getUserData();
      
      if (token != null && userData != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: userData,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        error: 'Failed to initialize authentication',
      );
    }
  }

  // Send OTP
  Future<Map<String, dynamic>?> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _apiService.sendOtp(phone: phone);
      
      if (response.isSuccess) {
        state = state.copyWith(isLoading: false);
        return response.data; // Returns {message, otp}
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send OTP: $e',
      );
      return null;
    }
  }

  // Verify OTP and login
  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _apiService.verifyOtp(phone: phone, otp: otp);
      
      if (response.isSuccess && response.data != null) {
        await _apiService.setAuthToken(response.data!.token);
        await _apiService.setUserData(response.data!.user);
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: response.data!.user,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to verify OTP: $e',
      );
      return false;
    }
  }

  // Register new user
  Future<bool> register({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _apiService.register(
        email: email,
        phone: phone,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      
      if (response.isSuccess && response.data != null) {
        await _apiService.setAuthToken(response.data!.token);
        await _apiService.setUserData(response.data!.user);
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: response.data!.user,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e',
      );
      return false;
    }
  }

  // Login with email and password
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _apiService.login(email: email, password: password);
      
      if (response.isSuccess && response.data != null) {
        await _apiService.setAuthToken(response.data!.token);
        await _apiService.setUserData(response.data!.user);
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: response.data!.user,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: $e',
      );
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? profilePictureUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _apiService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        profilePictureUrl: profilePictureUrl,
      );
      
      if (response.isSuccess && response.data != null) {
        await _apiService.setUserData(response.data!);
        
        state = state.copyWith(
          isLoading: false,
          user: response.data!,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Profile update failed: $e',
      );
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _apiService.logout();
      await _apiService.clearAuthData();
      
      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
      );
    } catch (e) {
      // Even if logout API fails, clear local data
      await _apiService.clearAuthData();
      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
      );
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final apiServiceProvider = Provider<ApiService>((ref) {
  final apiService = ApiService();
  apiService.initialize();
  return apiService;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthNotifier(apiService);
});

// Computed providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});
