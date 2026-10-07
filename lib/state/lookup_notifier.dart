import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/brand.dart';
import '../models/client.dart';
import '../models/entity.dart';
import '../models/mechanic.dart';
import '../models/service_item.dart';
import '../repositories/brand_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/mechanic_repository.dart';
import '../repositories/service_repository.dart';

/// Справочники для подписей, выпадающих списков и наборов фишек.
///
/// В записи автомобиля хранятся только идентификаторы, а в интерфейсе
/// нужно показать «Kia Rio», «Иванов С. П.» и имена мастеров. Варианты
/// выбора в формах берутся отсюда, то есть из репозиториев, а не из
/// констант в коде.
class LookupNotifier extends ChangeNotifier {
  LookupNotifier(
    this._brands,
    this._clients,
    this._mechanics,
    this._services, {
    Listenable? changes,
    bool Function()? active,
  }) : _changes = changes,
       _active = active {
    // После любой записи в хранилище справочники перечитываются: новая
    // марка сразу появляется в форме автомобиля.
    _changes?.addListener(load);
  }

  final BrandRepository _brands;
  final ClientRepository _clients;
  final MechanicRepository _mechanics;
  final ServiceRepository _services;
  final Listenable? _changes;

  /// Загружать ли справочники: до входа сервер ответит 401.
  final bool Function()? _active;

  Map<int, Brand> _brandById = const {};
  Map<int, Client> _clientById = const {};
  Map<int, Mechanic> _mechanicById = const {};
  Map<int, ServiceItem> _serviceById = const {};
  bool _loaded = false;
  bool _disposed = false;
  int _generation = 0;

  bool get loaded => _loaded;

  /// Действующие записи, отсортированные для показа в списках выбора.
  List<Brand> get brands => _live(_brandById, (b) => b.name);
  List<Client> get clients => _live(_clientById, (c) => c.fullName);
  List<Mechanic> get mechanics => _live(_mechanicById, (m) => m.fullName);
  List<ServiceItem> get services => _live(_serviceById, (s) => s.name);

  /// Все страны марок — для фильтра списка марок.
  List<String> get countries =>
      {for (final b in _brandById.values) b.country}.toList()..sort();

  static List<T> _live<T extends Entity>(
    Map<int, T> map,
    String Function(T) label,
  ) {
    final list = map.values.where((e) => !e.isDeleted).toList();
    list.sort(
      (a, b) => label(a).toLowerCase().compareTo(label(b).toLowerCase()),
    );
    return list;
  }

  Brand? brand(int id) => _brandById[id];
  Client? client(int id) => _clientById[id];
  Mechanic? mechanic(int id) => _mechanicById[id];
  ServiceItem? service(int id) => _serviceById[id];

  String brandName(int id) => _brandById[id]?.name ?? '—';
  String clientName(int id) => _clientById[id]?.shortName ?? 'Клиент #$id';
  String mechanicName(int id) => _mechanicById[id]?.shortName ?? 'Мастер #$id';
  String serviceName(int id) => _serviceById[id]?.name ?? 'Услуга #$id';

  Future<void> load() async {
    if (_active != null && !_active()) return;
    final generation = ++_generation;
    // Клиенту сервер не отдаёт списки клиентов и мастеров (403):
    // такие справочники остаются пустыми, остальные загружаются.
    Future<List<T>> allowed<T>(Future<List<T>> request) async {
      try {
        return await request;
      } on ForbiddenException {
        return const [];
      }
    }

    try {
      final brands = await allowed(_brands.findAll());
      final clients = await allowed(_clients.findAll());
      final mechanics = await allowed(_mechanics.findAll());
      final services = await allowed(_services.findAll());
      // Пока шла загрузка, могла начаться следующая — её данные новее.
      if (_disposed || generation != _generation) return;
      _brandById = {for (final b in brands) b.id: b};
      _clientById = {for (final c in clients) c.id: c};
      _mechanicById = {for (final m in mechanics) m.id: m};
      _serviceById = {for (final s in services) s.id: s};
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Без справочников списки всё равно работают: вместо названий
      // покажутся номера. Повторная попытка — при следующей загрузке.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _changes?.removeListener(load);
    super.dispose();
  }
}
