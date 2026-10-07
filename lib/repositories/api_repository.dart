import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/entity.dart';
import '../models/page_result.dart';
import 'data_changes.dart';
import 'entity_repository.dart';

/// Репозиторий поверх REST API. Интерфейс [EntityRepository] из ПР2
/// не изменился — поменялась только реализация.
///
/// Всё общее для пяти ресурсов — страницы, удаление, восстановление —
/// написано здесь один раз. Наследник задаёт адрес ресурса, разбор JSON
/// и параметры своих фильтров. Каждое обращение к сети обёрнуто в
/// [guard]: наружу выходят только исключения предметной области.
abstract class ApiRepository<T extends Entity, Q extends PagedQuery>
    implements EntityRepository<T, Q> {
  ApiRepository(
    this._dio, {
    required this.path,
    required this.changes,
    this.cacheAll = false,
  });

  final Dio _dio;

  /// Клиент Dio для операций, которые есть только у одного ресурса.
  @protected
  Dio get dio => _dio;

  /// Адрес ресурса относительно базового: `/cars`, `/brands`…
  final String path;
  final DataChanges changes;

  /// Справочник: полный список запрашивается один раз и хранится, пока
  /// записи этого ресурса не изменятся.
  final bool cacheAll;

  // ---- то, что описывает наследник ----

  T fromJson(Map<String, dynamic> json);

  /// Поиск и фильтры в виде параметров строки запроса.
  Map<String, Object> filterParameters(Q query);

  /// Тело запроса на создание и изменение: без id и отметки удаления.
  @protected
  Map<String, dynamic> toBody(T item) => item.toJson()
    ..remove('id')
    ..remove('deletedAt');

  // ---- чтение ----

  CancelToken? _findToken;

  /// Кэш справочника. Хранится сам запрос, а не только результат: если
  /// список нужен двум частям приложения одновременно, запрос уйдёт один.
  Future<List<T>>? _cache;

  @override
  Future<PageResult<T>> find(Q q) => guard(() async {
    // Отмена устаревшего запроса: при быстром вводе в поле поиска
    // ответ на «Ki» не должен прийти после ответа на «Kia» и затереть его.
    _findToken?.cancel('Запрос устарел');
    final token = _findToken = CancelToken();

    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {
        ...filterParameters(q),
        'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
        'page': q.page,
        'size': q.size,
        if (q.includeDeleted) 'includeDeleted': true,
      },
      cancelToken: token,
    );
    return _page(response.data!, q.size);
  });

  PageResult<T> _page(Map<String, dynamic> data, int size) => PageResult(
    items: (data['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(),
    page: data['page'] as int? ?? 1,
    size: data['size'] as int? ?? size,
    total: data['total'] as int? ?? 0,
  );

  @override
  Future<List<T>> findAll() {
    if (!cacheAll) return _loadAll();
    final future = _cache ??= _loadAll();
    // Неудачный запрос не кэшируется — следующая загрузка повторит его.
    future.then(
      (_) {},
      onError: (_) {
        if (identical(_cache, future)) _cache = null;
      },
    );
    return future;
  }

  Future<List<T>> _loadAll() => guard(() async {
    // Сервер отдаёт не больше 100 записей за раз — собираем по страницам.
    final all = <T>[];
    for (var page = 1; ; page++) {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {'includeDeleted': true, 'page': page, 'size': 100},
      );
      final result = _page(response.data!, 100);
      all.addAll(result.items);
      if (result.items.isEmpty || all.length >= result.total) break;
    }
    return List<T>.unmodifiable(all);
  });

  @override
  Future<T?> findById(int id) async {
    try {
      return await guard(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '$path/$id',
          // Удалённую запись тоже можно открыть — чтобы восстановить.
          queryParameters: {'includeDeleted': true},
        );
        return fromJson(response.data!);
      });
    } on NotFoundException {
      return null;
    }
  }

  // ---- запись ----

  @override
  Future<T> create(T entity) => _write(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: toBody(entity),
    );
    return fromJson(response.data!);
  });

  @override
  Future<T> update(T entity) => _write(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '$path/${entity.id}',
      data: toBody(entity),
    );
    return fromJson(response.data!);
  });

  @override
  Future<void> softDelete(int id) => _write(() => _dio.delete('$path/$id'));

  @override
  Future<void> hardDelete(int id) =>
      _write(() => _dio.delete('$path/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) => _write(() => _dio.post('$path/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => _write(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$path/bulk-delete',
      data: {'ids': ids},
    );
    return response.data?['deleted'] as int? ?? 0;
  });

  /// После успешной записи кэш справочника устаревает, а остальные части
  /// приложения узнают об изменении.
  Future<R> _write<R>(Future<R> Function() action) async {
    final result = await guard(action);
    _cache = null;
    changes.changed();
    return result;
  }
}
