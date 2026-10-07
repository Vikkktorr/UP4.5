import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';

/// Статистика для экрана администратора.
class Stats {
  const Stats({
    required this.counts,
    required this.deleted,
    required this.users,
    required this.servicePrice,
  });

  /// Действующие записи по ресурсам: cars, clients, brands…
  final Map<String, int> counts;

  /// Логически удалённые записи по ресурсам.
  final Map<String, int> deleted;

  /// Пользователи по ролям: client, mechanic, admin.
  final Map<String, int> users;

  /// Стоимость услуг по всем действующим автомобилям, ₽.
  final int servicePrice;

  static Map<String, int> _map(Object? json) =>
      (json as Map).map((k, v) => MapEntry('$k', v as int));

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
    counts: _map(json['counts']),
    deleted: _map(json['deleted']),
    users: _map(json['users']),
    servicePrice: json['servicePrice'] as int,
  );
}

/// Операции администратора: пользователи, роли, статистика.
/// Сервер выполняет их только для роли admin, остальным отвечает 403.
class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  Future<List<AppUser>> users() => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/users');
    return [
      for (final json in response.data!['items'] as List)
        AppUser.fromJson(json as Map<String, dynamic>),
    ];
  });

  Future<void> setRole(int id, Role role) => guard(() async {
    await _dio.patch<void>('/users/$id', data: {'role': role.name});
  });

  Future<void> deleteUser(int id) => guard(() async {
    await _dio.delete<void>('/users/$id');
  });

  Future<Stats> stats() => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/stats');
    return Stats.fromJson(response.data!);
  });
}
