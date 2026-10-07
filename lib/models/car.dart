import '../core/json.dart';
import 'entity.dart';
import 'fuel_type.dart';

/// Автомобиль клиента. Основная сущность приложения.
///
/// Связи: [brandId] и [clientId] — многие к одному с маркой и владельцем,
/// [mechanicIds] и [serviceIds] — многие ко многим с мастерами и услугами.
/// Связи хранятся идентификаторами, а не объектами: так запись без потерь
/// переводится в JSON и обратно.
class Car implements Entity {
  @override
  final int id;

  /// Госномер в виде «А123ВС777», без пробелов.
  final String plate;
  final String vin;
  final int brandId;
  final String model;
  final int year;

  /// Пробег в километрах.
  final int mileage;
  final FuelType fuel;
  final int clientId;

  /// Мастера, закреплённые за автомобилем.
  final List<int> mechanicIds;

  /// Услуги в текущем заказе.
  final List<int> serviceIds;
  @override
  final DateTime? deletedAt;

  const Car({
    required this.id,
    required this.plate,
    required this.vin,
    required this.brandId,
    required this.model,
    required this.year,
    required this.mileage,
    required this.fuel,
    required this.clientId,
    this.mechanicIds = const [],
    this.serviceIds = const [],
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  Car copyWith({
    int? id,
    String? plate,
    String? vin,
    int? brandId,
    String? model,
    int? year,
    int? mileage,
    FuelType? fuel,
    int? clientId,
    List<int>? mechanicIds,
    List<int>? serviceIds,
    DateTime? deletedAt,
    // Без этого флага нельзя отличить «не менять deletedAt» от «сбросить
    // в null»: в обоих случаях параметр deletedAt равен null.
    bool clearDeletedAt = false,
  }) {
    return Car(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      vin: vin ?? this.vin,
      brandId: brandId ?? this.brandId,
      model: model ?? this.model,
      year: year ?? this.year,
      mileage: mileage ?? this.mileage,
      fuel: fuel ?? this.fuel,
      clientId: clientId ?? this.clientId,
      mechanicIds: mechanicIds ?? this.mechanicIds,
      serviceIds: serviceIds ?? this.serviceIds,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'plate': plate,
    'vin': vin,
    'brandId': brandId,
    'model': model,
    'year': year,
    'mileage': mileage,
    'fuel': fuel.code,
    'clientId': clientId,
    'mechanicIds': mechanicIds,
    'serviceIds': serviceIds,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  /// Разбирает обе формы записи. На запись сервер принимает brandId,
  /// clientId, mechanicIds, serviceIds, а на чтение отдаёт развёрнутые
  /// объекты brand, client, mechanics, services. Форма и хранилище формы
  /// работают с идентификаторами — их и достаём из любого варианта.
  factory Car.fromJson(Map<String, dynamic> json) => Car(
    id: readInt(json, 'id'),
    plate: readString(json, 'plate'),
    vin: readString(json, 'vin'),
    brandId:
        readIntOrNull(json, 'brandId') ?? readInt(readMap(json, 'brand'), 'id'),
    model: readString(json, 'model'),
    year: readInt(json, 'year'),
    mileage: readInt(json, 'mileage'),
    // Неизвестный код двигателя не должен ронять разбор всего списка.
    fuel: FuelType.fromCode(json['fuel'] as Object?) ?? FuelType.petrol,
    clientId:
        readIntOrNull(json, 'clientId') ??
        readInt(readMap(json, 'client'), 'id'),
    mechanicIds: json.containsKey('mechanicIds')
        ? readIntList(json, 'mechanicIds')
        : readIdsOf(json, 'mechanics'),
    serviceIds: json.containsKey('serviceIds')
        ? readIntList(json, 'serviceIds')
        : readIdsOf(json, 'services'),
    deletedAt: readDateOrNull(json, 'deletedAt'),
  );
}
