import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';

/// Ответ сервера на вход, регистрацию и обновление токена.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}

/// Адреса /auth/* учебного API.
///
/// Пароль уходит на сервер как есть: хеширует его сервер. Хеш, посчитанный
/// в браузере, ничего не защищает — он просто становится новым паролем.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResult> login(String username, String password) => guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return AuthResult.fromJson(response.data!);
  });

  Future<AuthResult> register({
    required String username,
    required String password,
    required String lastName,
    required String firstName,
  }) => guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'username': username,
        'password': password,
        'lastName': lastName,
        'firstName': firstName,
      },
    );
    return AuthResult.fromJson(response.data!);
  });

  /// Кто владелец токена. 401 — токен истёк или подделан.
  Future<AppUser> me(String accessToken) => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return AppUser.fromJson(response.data!);
  });

  Future<AuthResult> refresh(String refreshToken) => guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthResult.fromJson(response.data!);
  });
}
