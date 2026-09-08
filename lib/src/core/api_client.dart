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
          baseUrl: normalizeBaseUrl(
            baseUrl ??
                const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'https://tktsapp.com/api/v1',
                ),
          ),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      );

  final Dio _dio;
  String? _token;

  /// Accepts the deployment origin as well as a full API URL. This protects
  /// release builds when a CI variable contains `https://tktsapp.com` rather
  /// than the required `/api/v1` path.
  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return 'https://tktsapp.com/api/v1';
    }

    final path = parsed.path.replaceAll(RegExp(r'/+$'), '');
    final apiPath = path.endsWith('/api/v1')
        ? path
        : path.endsWith('/api')
        ? '$path/v1'
        : path.isEmpty
        ? '/api/v1'
        : '$path/api/v1';

    return parsed.replace(path: apiPath, query: null, fragment: null).toString();
  }

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
    if (error.type == DioExceptionType.badCertificate) {
      return 'A secure connection to TKTSAPP could not be established.';
    }
    if (error.response?.statusCode == 404) {
      return 'The TKTSAPP Scanner service is unavailable. Please update the app or try again.';
    }
    if ((error.response?.statusCode ?? 0) >= 500) {
      return 'TKTSAPP is temporarily unavailable. Please try again shortly.';
    }
    return 'The request could not be completed. Please try again.';
  }
}
