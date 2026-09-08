import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl:
              baseUrl ??
              const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'https://tktsapp.com/api/v1',
              ),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      );

  final Dio _dio;
  String? _token;

  void setToken(String? token) => _token = token;
  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, {Object? data}) =>
      _request('POST', path, data: data);
  Future<Map<String, dynamic>> patch(String path, {Object? data}) =>
      _request('PATCH', path, data: data);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? data,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: _token == null ? null : {'Authorization': 'Bearer $_token'},
        ),
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const {};
    } on DioException catch (error) {
      final payload = error.response?.data;
      final message = payload is Map
          ? (payload['message']?.toString() ?? _fallback(error))
          : _fallback(error);
      throw ApiFailure(message, statusCode: error.response?.statusCode);
    }
  }

  String _fallback(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Cannot reach TKTSAPP. Check your connection and try again.';
    }
    return 'The request could not be completed. Please try again.';
  }
}
