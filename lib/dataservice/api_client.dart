import 'package:dio/dio.dart';
import 'package:productivity/dataservice/login_service.dart';

// ─────────────────────────────────────────────
//  Central API Client
//  All services use this singleton Dio instance.
//  The auth interceptor automatically attaches
//  the Bearer token to every request.
// ─────────────────────────────────────────────
class ApiClient {
  ApiClient._();

  static const String baseUrl = 'http://192.168.178.20:8000/api';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(_AuthInterceptor());

  static Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await LoginService.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // On 401 the token is likely expired – caller handles redirect to login.
    handler.next(err);
  }
}
