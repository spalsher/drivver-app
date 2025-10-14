import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.requestTimeout,
      receiveTimeout: AppConstants.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors for logging and error handling
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => debugPrint('🚀 API: $object'),
      ));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('🚀 API Request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('✅ API Response: ${response.statusCode} ${response.requestOptions.uri}');
        if (response.data != null) {
          debugPrint('📥 Response Data: ${response.data}');
        }
        handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('❌ API Error: ${error.message}');
        if (error.response != null) {
          debugPrint('📥 Error Data: ${error.response?.data}');
        }
        handler.next(error);
      },
    ));
  }

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp({required String phone}) async {
    try {
      debugPrint('🚀 Sending OTP request to: ${AppConstants.baseUrl}/auth/send-otp');
      debugPrint('📱 Phone number: $phone');
      
      final response = await _dio.post(
        '/auth/send-otp',
        data: {
          'phone': phone,
        },
      );

      debugPrint('✅ OTP Response: ${response.data}');
      return {
        'success': true,
        'message': response.data['message'] ?? 'OTP sent successfully',
        'otp': response.data['otp'], // Development OTP
      };
    } on DioException catch (e) {
      debugPrint('❌ Send OTP DioException: ${e.message}');
      debugPrint('❌ Response: ${e.response?.data}');
      debugPrint('❌ Status Code: ${e.response?.statusCode}');
      return {
        'success': false,
        'error': e.response?.data['error'] ?? 'Failed to send OTP',
      };
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Failed to send OTP: $e',
      };
    }
  }

  /// Verify OTP and login driver
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify-otp',
        data: {
          'phone': phone,
          'otp': otp,
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'OTP verified successfully',
        'token': response.data['token'],
        'user': response.data['user'],
      };
    } on DioException catch (e) {
      debugPrint('❌ Verify OTP Error: ${e.message}');
      return {
        'success': false,
        'error': e.response?.data['error'] ?? 'Failed to verify OTP',
      };
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Failed to verify OTP: $e',
      };
    }
  }

  /// Get driver profile
  Future<Map<String, dynamic>> getDriverProfile() async {
    try {
      final response = await _dio.get('/users/profile');

      return {
        'success': true,
        'user': response.data['user'],
      };
    } on DioException catch (e) {
      debugPrint('❌ Get Profile Error: ${e.message}');
      return {
        'success': false,
        'error': e.response?.data['error'] ?? 'Failed to get profile',
      };
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Failed to get profile: $e',
      };
    }
  }

  /// Update driver profile
  Future<Map<String, dynamic>> updateDriverProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/users/profile', data: data);

      return {
        'success': true,
        'message': response.data['message'] ?? 'Profile updated successfully',
        'user': response.data['user'],
      };
    } on DioException catch (e) {
      debugPrint('❌ Update Profile Error: ${e.message}');
      return {
        'success': false,
        'error': e.response?.data['error'] ?? 'Failed to update profile',
      };
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Failed to update profile: $e',
      };
    }
  }

  /// Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    debugPrint('🔑 Auth token set for API requests');
  }

  /// Clear authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
    debugPrint('🔑 Auth token cleared');
  }

  // Document Verification APIs

  /// Get driver documents status
  Future<Map<String, dynamic>> getDriverDocuments() async {
    try {
      final response = await _dio.get('/drivers/documents');
      return {
        'success': true,
        'documents': response.data['documents'] ?? [],
      };
    } on DioException catch (e) {
      debugPrint('❌ Get Documents Error: ${e.message}');
      return {
        'success': false,
        'error': e.response?.data['error'] ?? 'Failed to fetch documents',
      };
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Failed to fetch documents: $e',
      };
    }
  }

  /// Upload document
  Future<Map<String, dynamic>> uploadDocument(FormData formData) async {
    try {
      final response = await _dio.post('/drivers/documents/upload', data: formData);
      return {
        'success': true,
        'filePath': response.data['filePath'],
        'message': response.data['message'] ?? 'Document uploaded successfully',
      };
    } on DioException catch (e) {
      debugPrint('❌ Upload Document Error: ${e.message}');
      return {
        'success': false,
        'error': e.response?.data['error'] ?? 'Failed to upload document',
      };
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Failed to upload document: $e',
      };
    }
  }

  /// Delete document
  Future<Map<String, dynamic>> deleteDocument(String documentType) async {
    try {
      final response = await _dio.delete('/drivers/documents/$documentType');
      return {
        'success': true,
        'message': response.data['message'] ?? 'Document deleted successfully',
      };
    } on DioException catch (e) {
      debugPrint('❌ Delete Document Error: ${e.message}');
      return {
        'success': false,
        'error': e.response?.data['error'] ?? 'Failed to delete document',
      };
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Failed to delete document: $e',
      };
    }
  }

  /// Get verification status
  Future<Map<String, dynamic>> getVerificationStatus() async {
    try {
      debugPrint('🔍 Fetching verification status from backend...');
      final response = await _dio.get('/drivers/verification-status');
      debugPrint('✅ Verification status response: ${response.data}');
      
      return {
        'success': true,
        'status': response.data['status'],
        'isFullyVerified': response.data['isFullyVerified'] ?? false,
        'approvedCount': response.data['approvedCount'] ?? 0,
        'totalRequired': response.data['totalRequired'] ?? 5,
        'verificationLevel': response.data['verificationLevel'] ?? 'pending',
        'documents': response.data['documents'] ?? {},
      };
    } on DioException catch (e) {
      debugPrint('❌ Get Verification Status Error: ${e.message}');
      debugPrint('❌ Response: ${e.response?.data}');
      return {
        'success': false,
        'error': e.response?.data['error'] ?? 'Failed to fetch verification status',
      };
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return {
        'success': false,
        'error': 'Failed to fetch verification status: $e',
      };
    }
  }
}
