import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _driverData;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get driverData => _driverData;
  
  // Get driver ID from storage or driver data
  Future<String?> getDriverId() async {
    // Try from driver data first
    if (_driverData != null && _driverData!['id'] != null) {
      return _driverData!['id'];
    }
    
    // Fallback to secure storage
    try {
      return await _secureStorage.read(key: 'driver_id');
    } catch (e) {
      debugPrint('❌ Error getting driver ID: $e');
      return null;
    }
  }

  // Initialize auth provider
  Future<void> initialize() async {
    _apiService.initialize();
    await _checkAuthStatus();
  }

  // Check if driver is already authenticated
  Future<void> _checkAuthStatus() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token != null) {
        _apiService.setAuthToken(token);
        
        // Verify token is still valid by fetching profile
        final result = await _apiService.getDriverProfile();
        if (result['success']) {
          _isAuthenticated = true;
          _driverData = result['user'];
          debugPrint('🔑 Driver authenticated from stored token');
        } else {
          // Token is invalid, clear it
          await _clearAuthData();
          debugPrint('🔑 Stored token is invalid, clearing auth data');
        }
      }
    } catch (e) {
      debugPrint('❌ Auth check error: $e');
      await _clearAuthData();
    }
    notifyListeners();
  }

  // Send OTP
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _apiService.sendOtp(phone: phone);
      
      if (result['success']) {
        debugPrint('✅ OTP sent successfully to $phone');
        return {
          'success': true,
          'message': result['message'],
          'otp': result['otp'], // Development OTP
        };
      } else {
        _setError(result['error']);
        return {
          'success': false,
          'error': result['error'],
        };
      }
    } catch (e) {
      _setError('Failed to send OTP: $e');
      return {
        'success': false,
        'error': 'Failed to send OTP: $e',
      };
    } finally {
      _setLoading(false);
    }
  }

  // Verify OTP and login
  Future<bool> verifyOtp(String phone, String otp) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _apiService.verifyOtp(phone: phone, otp: otp);
      
      if (result['success']) {
        // Store auth data
        await _secureStorage.write(key: 'auth_token', value: result['token']);
        await _secureStorage.write(key: 'driver_id', value: result['user']['id']);
        await _secureStorage.write(key: 'driver_phone', value: phone);
        
        // Set API token
        _apiService.setAuthToken(result['token']);
        
        // Update state
        _isAuthenticated = true;
        _driverData = result['user'];
        
        debugPrint('✅ Driver authenticated successfully');
        notifyListeners();
        return true;
      } else {
        _setError(result['error']);
        return false;
      }
    } catch (e) {
      _setError('Failed to verify OTP: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    await _clearAuthData();
    _isAuthenticated = false;
    _driverData = null;
    _apiService.clearAuthToken();
    debugPrint('🔑 Driver logged out');
    notifyListeners();
  }

  // Load driver profile
  Future<bool> loadDriverProfile() async {
    if (!_isAuthenticated) return false;
    
    _setLoading(true);
    _clearError();

    try {
      final result = await _apiService.getDriverProfile();
      
      if (result['success']) {
        _driverData = result['user'];
        debugPrint('✅ Driver profile loaded successfully');
        notifyListeners();
        return true;
      } else {
        // If driver profile doesn't exist, it means user hasn't registered as driver yet
        // This is normal for new users who just completed OTP verification
        debugPrint('ℹ️ Driver profile not found - user may need to complete registration');
        _setError('Please complete your driver registration');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to load profile: $e');
      _setError('Failed to load profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update driver profile
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _apiService.updateDriverProfile(profileData);
      
      if (result['success']) {
        _driverData = result['user'];
        debugPrint('✅ Driver profile updated successfully');
        notifyListeners();
        return true;
      } else {
        _setError(result['error']);
        return false;
      }
    } catch (e) {
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }


  // Get stored phone number
  Future<String?> getDriverPhone() async {
    return await _secureStorage.read(key: 'driver_phone');
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _clearAuthData() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'driver_id');
    await _secureStorage.delete(key: 'driver_phone');
  }
}
