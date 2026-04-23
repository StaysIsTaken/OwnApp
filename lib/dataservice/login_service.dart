import 'package:dio/dio.dart';
import 'package:productivity/dataclasses/User.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginService {
  static const String baseUrl = 'http://192.168.178.20:8000/api/auth';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // ─── Register ─────────────────────────────────────────────────────────────
  static Future<void> register({
    required String username,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    await _dio.post(
      '/register',
      data: {
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
      },
    );
  }

  // ─── Login ────────────────────────────────────────────────────────────────
  static Future<void> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      '/login',
      data: {'username': username, 'password': password},
    );
    final token = response.data['access_token'];
    await _saveToken(token);
  }

  // ─── Registration Status ──────────────────────────────────────────────────
  static Future<bool> isRegistrationOpen() async {
    try {
      final response = await _dio.get('/registration-status');
      return response.data['open'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─── Token ────────────────────────────────────────────────────────────────
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  static Future<User> get currentUser async {
    final token = await getToken();

    final response = await _dio.get(
      '/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    throw Exception('Failed to fetch current user');
  }
}
