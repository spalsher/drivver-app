import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class UserService {
  static final Dio _dio = Dio();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  /// Get user profile from backend
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      print('🚀 API Request: GET ${AppConstants.baseUrl}/users/profile');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ No auth token found');
        return null;
      }

      final response = await _dio.get(
        '${AppConstants.baseUrl}/users/profile',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('✅ API Response: ${response.statusCode} ${AppConstants.baseUrl}/users/profile');
      print('📥 Response Data: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        print('❌ API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ API Error: $e');
      return null;
    }
  }

  /// Update user profile
  static Future<Map<String, dynamic>?> updateUserProfile({
    String? firstName,
    String? lastName,
    String? profilePhoto,
    String? homeAddress,
    String? workAddress,
    String? gender,
    Map<String, dynamic>? safetyPreferences,
    String? themePreference,
  }) async {
    try {
      print('🚀 API Request: PUT ${AppConstants.baseUrl}/users/profile');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ No auth token found');
        return null;
      }

      final requestData = <String, dynamic>{};
      if (firstName != null) requestData['firstName'] = firstName;
      if (lastName != null) requestData['lastName'] = lastName;
      if (profilePhoto != null) requestData['profilePhoto'] = profilePhoto;
      if (homeAddress != null) requestData['homeAddress'] = homeAddress;
      if (workAddress != null) requestData['workAddress'] = workAddress;
      if (gender != null) requestData['gender'] = gender;
      if (safetyPreferences != null) requestData['safetyPreferences'] = safetyPreferences;
      if (themePreference != null) requestData['themePreference'] = themePreference;

      print('📤 Request Data: $requestData');

      final response = await _dio.put(
        '${AppConstants.baseUrl}/users/profile',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('✅ API Response: ${response.statusCode} ${AppConstants.baseUrl}/users/profile');
      print('📥 Response Data: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        print('❌ API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ API Error: $e');
      return null;
    }
  }

  /// Save user address
  static Future<Map<String, dynamic>?> saveAddress({
    required String type,
    required String address,
    double? latitude,
    double? longitude,
    String? label,
  }) async {
    try {
      print('🚀 API Request: POST ${AppConstants.baseUrl}/users/addresses');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ No auth token found');
        return null;
      }

      final requestData = {
        'type': type,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      };

      print('📤 Request Data: $requestData');

      final response = await _dio.post(
        '${AppConstants.baseUrl}/users/addresses',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('✅ API Response: ${response.statusCode} ${AppConstants.baseUrl}/users/addresses');
      print('📥 Response Data: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        print('❌ API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ API Error: $e');
      return null;
    }
  }

  /// Get user saved addresses
  static Future<List<Map<String, dynamic>>?> getUserAddresses() async {
    try {
      print('🚀 API Request: GET ${AppConstants.baseUrl}/users/addresses');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ No auth token found');
        return null;
      }

      final response = await _dio.get(
        '${AppConstants.baseUrl}/users/addresses',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('✅ API Response: ${response.statusCode} ${AppConstants.baseUrl}/users/addresses');
      print('📥 Response Data: ${response.data}');

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['addresses'] ?? []);
      } else {
        print('❌ API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ API Error: $e');
      return null;
    }
  }
}
