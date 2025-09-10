class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    required this.message,
    this.statusCode,
    this.errors,
  });

  factory ApiResponse.success({
    T? data,
    String message = 'Success',
  }) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
      message: message,
    );
  }

  factory ApiResponse.error({
    required String message,
    int? statusCode,
    Map<String, dynamic>? errors,
  }) {
    return ApiResponse._(
      isSuccess: false,
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }

  bool get isError => !isSuccess;

  @override
  String toString() {
    return 'ApiResponse(isSuccess: $isSuccess, message: $message, statusCode: $statusCode)';
  }
}
