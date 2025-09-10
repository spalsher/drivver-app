import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/api_response_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Initialize the API service
  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add request interceptor for authentication
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          print('🚀 API Request: ${options.method} ${options.uri}');
          if (options.data != null) {
            print('📤 Request Data: ${options.data}');
          }
          
          handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ API Response: ${response.statusCode} ${response.requestOptions.uri}');
          print('📥 Response Data: ${response.data}');
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ API Error: ${error.message}');
          print('🔍 Error Response: ${error.response?.data}');
          
          // Handle token expiration
          if (error.response?.statusCode == 401) {
            _handleUnauthorized();
          }
          
          handler.next(error);
        },
      ),
    );
  }

  // Handle unauthorized access (token expired)
  Future<void> _handleUnauthorized() async {
    await clearAuthData();
    // You can add navigation to login screen here if needed
  }

  // Auth Token Management
  Future<String?> getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> setAuthToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> clearAuthData() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'onboarding_completed');
    print('🔐 Cleared all authentication data');
  }

  Future<void> setUserData(UserModel user) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUserData() async {
    final userData = await _storage.read(key: 'user_data');
    if (userData != null) {
      return UserModel.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // Generic API request method
  Future<ApiResponse<T>> _request<T>(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _dio.get(endpoint, queryParameters: queryParameters);
          break;
        case 'POST':
          response = await _dio.post(endpoint, data: data, queryParameters: queryParameters);
          break;
        case 'PUT':
          response = await _dio.put(endpoint, data: data, queryParameters: queryParameters);
          break;
        case 'DELETE':
          response = await _dio.delete(endpoint, queryParameters: queryParameters);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Handle successful response
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        T? result;
        if (fromJson != null && response.data != null) {
          result = fromJson(response.data);
        }
        
        return ApiResponse.success(
          data: result,
          message: (response.data is Map<String, dynamic>) 
            ? (response.data['message'] ?? 'Success')
            : 'Success',
        );
      } else {
        return ApiResponse.error(
          message: (response.data is Map<String, dynamic>) 
            ? (response.data['message'] ?? 'Request failed')
            : 'Request failed',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse.error(
        message: 'Unexpected error: $e',
        statusCode: 500,
      );
    }
  }

  // Handle Dio errors
  ApiResponse<T> _handleDioError<T>(DioException error) {
    String message;
    int? statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.badResponse:
        message = error.response?.data['message'] ?? 
                 error.response?.data['error'] ?? 
                 'Server error occurred';
        break;
      case DioExceptionType.cancel:
        message = 'Request was cancelled';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection. Please check your network.';
        break;
      default:
        message = 'Network error occurred. Please try again.';
    }

    return ApiResponse.error(
      message: message,
      statusCode: statusCode,
    );
  }

  // Health check
  Future<ApiResponse<Map<String, dynamic>>> healthCheck() async {
    return _request<Map<String, dynamic>>(
      'GET',
      '/health',
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }

  // Authentication APIs
  Future<ApiResponse<AuthResponse>> register({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return _request<AuthResponse>(
      'POST',
      '/auth/register',
      data: {
        'email': email,
        'phone': phone,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      },
      fromJson: (data) => AuthResponse.fromJson(data),
    );
  }

  Future<ApiResponse<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    return _request<AuthResponse>(
      'POST',
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
      fromJson: (data) => AuthResponse.fromJson(data),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> sendOtp({
    required String phone,
  }) async {
    return _request<Map<String, dynamic>>(
      'POST',
      '/auth/send-otp',
      data: {
        'phone': phone,
      },
      fromJson: (data) => {
        'message': data['message'] as String,
        'otp': data['otp'] as String?, // Development OTP
      },
    );
  }

  Future<ApiResponse<AuthResponse>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    return _request<AuthResponse>(
      'POST',
      '/auth/verify-otp',
      data: {
        'phone': phone,
        'otp': otp,
      },
      fromJson: (data) => AuthResponse.fromJson(data),
    );
  }

  Future<ApiResponse<void>> logout() async {
    final response = await _request<void>('POST', '/auth/logout');
    if (response.isSuccess) {
      await clearAuthData();
    }
    return response;
  }

  // User APIs
  Future<ApiResponse<UserModel>> getCurrentUser() async {
    return _request<UserModel>(
      'GET',
      '/users/profile',
      fromJson: (data) => UserModel.fromJson(data['user']),
    );
  }

  Future<ApiResponse<UserModel>> updateProfile({
    required String firstName,
    required String lastName,
    String? profilePictureUrl,
  }) async {
    return _request<UserModel>(
      'PUT',
      '/users/profile',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        if (profilePictureUrl != null) 'profile_picture_url': profilePictureUrl,
      },
      fromJson: (data) => UserModel.fromJson(data['user']),
    );
  }

  // Ride APIs
  Future<ApiResponse<RideRequest>> createRideRequest({
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationAddress,
    required double fareOffer,
    int passengerCount = 1,
    String? specialInstructions,
  }) async {
    return _request<RideRequest>(
      'POST',
      '/rides/request',
      data: {
        'pickup_location': {'lat': pickupLatitude, 'lng': pickupLongitude},
        'pickup_address': pickupAddress,
        'destination_location': {'lat': destinationLatitude, 'lng': destinationLongitude},
        'destination_address': destinationAddress,
        'customer_fare_offer': fareOffer,
        'passenger_count': passengerCount,
        if (specialInstructions != null) 'special_instructions': specialInstructions,
      },
      fromJson: (data) => RideRequest.fromJson(data['ride_request']),
    );
  }

  Future<ApiResponse<List<HagglingOffer>>> getRideOffers(String rideRequestId) async {
    return _request<List<HagglingOffer>>(
      'GET',
      '/rides/$rideRequestId/offers',
      fromJson: (data) => (data['offers'] as List)
          .map((offer) => HagglingOffer.fromJson(offer))
          .toList(),
    );
  }

  Future<ApiResponse<HagglingOffer>> acceptOffer(String offerId) async {
    return _request<HagglingOffer>(
      'POST',
      '/rides/offers/$offerId/accept',
      fromJson: (data) => HagglingOffer.fromJson(data['offer']),
    );
  }

  Future<ApiResponse<HagglingOffer>> counterOffer({
    required String offerId,
    required double counterOfferAmount,
  }) async {
    return _request<HagglingOffer>(
      'POST',
      '/rides/offers/$offerId/counter',
      data: {
        'customer_counter_offer': counterOfferAmount,
      },
      fromJson: (data) => HagglingOffer.fromJson(data['offer']),
    );
  }

  Future<ApiResponse<List<Trip>>> getTripHistory({
    int page = 1,
    int limit = 20,
  }) async {
    return _request<List<Trip>>(
      'GET',
      '/rides/history',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
      fromJson: (data) => (data['trips'] as List)
          .map((trip) => Trip.fromJson(trip))
          .toList(),
    );
  }

  Future<ApiResponse<Trip>> rateTrip({
    required String tripId,
    required int rating,
    String? review,
  }) async {
    return _request<Trip>(
      'POST',
      '/rides/trips/$tripId/rate',
      data: {
        'customer_rating': rating,
        if (review != null) 'customer_review': review,
      },
      fromJson: (data) => Trip.fromJson(data['trip']),
    );
  }

  // Upload file (for profile pictures, etc.)
  Future<ApiResponse<String>> uploadFile(File file, String endpoint) async {
    try {
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });

      final response = await _dio.post(endpoint, data: formData);

      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        return ApiResponse.success(
          data: response.data['url'] as String,
          message: 'File uploaded successfully',
        );
      } else {
        return ApiResponse.error(
          message: response.data['message'] ?? 'Upload failed',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse.error(
        message: 'Upload error: $e',
        statusCode: 500,
      );
    }
  }
}

// Auth response model
class AuthResponse {
  final UserModel user;
  final String token;

  AuthResponse({
    required this.user,
    required this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserModel.fromJson(json['user']),
      token: json['token'],
    );
  }
}

// Ride request model
class RideRequest {
  final String id;
  final String customerId;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationAddress;
  final double customerFareOffer;
  final int passengerCount;
  final String? specialInstructions;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;

  RideRequest({
    required this.id,
    required this.customerId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationAddress,
    required this.customerFareOffer,
    required this.passengerCount,
    this.specialInstructions,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'],
      customerId: json['customer_id'],
      pickupLatitude: json['pickup_latitude'].toDouble(),
      pickupLongitude: json['pickup_longitude'].toDouble(),
      pickupAddress: json['pickup_address'],
      destinationLatitude: json['destination_latitude'].toDouble(),
      destinationLongitude: json['destination_longitude'].toDouble(),
      destinationAddress: json['destination_address'],
      customerFareOffer: json['customer_fare_offer'].toDouble(),
      passengerCount: json['passenger_count'],
      specialInstructions: json['special_instructions'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }
}

// Haggling offer model
class HagglingOffer {
  final String id;
  final String rideRequestId;
  final String driverId;
  final double driverFareOffer;
  final double? customerCounterOffer;
  final double? driverCounterOffer;
  final int offerRound;
  final String status;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  HagglingOffer({
    required this.id,
    required this.rideRequestId,
    required this.driverId,
    required this.driverFareOffer,
    this.customerCounterOffer,
    this.driverCounterOffer,
    required this.offerRound,
    required this.status,
    required this.expiresAt,
    this.acceptedAt,
    required this.createdAt,
  });

  factory HagglingOffer.fromJson(Map<String, dynamic> json) {
    return HagglingOffer(
      id: json['id'],
      rideRequestId: json['ride_request_id'],
      driverId: json['driver_id'],
      driverFareOffer: json['driver_fare_offer'].toDouble(),
      customerCounterOffer: json['customer_counter_offer']?.toDouble(),
      driverCounterOffer: json['driver_counter_offer']?.toDouble(),
      offerRound: json['offer_round'],
      status: json['status'],
      expiresAt: DateTime.parse(json['expires_at']),
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

// Trip model
class Trip {
  final String id;
  final String customerId;
  final String driverId;
  final double finalFare;
  final DateTime? startTime;
  final DateTime? endTime;
  final String status;
  final int? customerRating;
  final int? driverRating;
  final String? customerReview;
  final String? driverReview;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.customerId,
    required this.driverId,
    required this.finalFare,
    this.startTime,
    this.endTime,
    required this.status,
    this.customerRating,
    this.driverRating,
    this.customerReview,
    this.driverReview,
    required this.createdAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      customerId: json['customer_id'],
      driverId: json['driver_id'],
      finalFare: json['final_fare'].toDouble(),
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      status: json['status'],
      customerRating: json['customer_rating'],
      driverRating: json['driver_rating'],
      customerReview: json['customer_review'],
      driverReview: json['driver_review'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
