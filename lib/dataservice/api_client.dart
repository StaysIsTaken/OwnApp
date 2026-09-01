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

  // Wird beim Build via --dart-define=API_URL=... gesetzt (siehe Dockerfile
  // und deploy.yml). Ohne gesetzten Wert bleibt es bei der Produktiv-URL –
  // ein leerer String wuerde sonst jede Anfrage ins Leere laufen lassen.
  static const String _envUrl = String.fromEnvironment('API_URL');
  static const String baseUrl =
      _envUrl == '' ? 'https://api.home-anft.de/api' : _envUrl;

  /// Wird aufgerufen, wenn das Backend 401 liefert – also wenn das Token
  /// abgelaufen oder ungültig ist. Der UserProvider hängt sich hier ein und
  /// wirft den Nutzer zurück auf den Login, statt ihn mit lauter
  /// Netzwerkfehlern sitzen zu lassen.
  static void Function()? onUnauthorized;

  /// Wird bei 403 gerufen. Ein fehlendes Recht heisst fast immer, dass sich
  /// die Rollen geaendert haben, seit die App ihre Rechte geladen hat — der
  /// PermissionProvider haengt sich hier ein und holt sie neu, damit das
  /// Menue sich von selbst berichtigt statt bis zum naechsten Start falsch
  /// zu bleiben.
  static void Function()? onForbidden;

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(_AuthInterceptor());

  static Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  /// Endpunkte, deren 401 eine fehlgeschlagene Anmeldung bedeutet – nicht ein
  /// abgelaufenes Token. Die dürfen keinen Auto-Logout auslösen.
  static const _authPaths = {'/auth/login', '/auth/register'};

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
    if (err.response?.statusCode == 403) {
      ApiClient.onForbidden?.call();
    }
    final isAuthRequest = _authPaths.any(err.requestOptions.path.endsWith);
    if (err.response?.statusCode == 401 && !isAuthRequest) {
      LoginService.logout();
      ApiClient.onUnauthorized?.call();
    }
    handler.next(err);
  }
}
