import '../core/json.dart';
import 'entity.dart';

enum ServiceCategory {
  maintenance('maintenance', 'Техобслуживание'),
  engine('engine', 'Двигатель'),
  chassis('chassis', 'Ходовая часть'),
  electrics('electrics', 'Электрика'),
  body('body', 'Кузов'),
  tires('tires', 'Шиномонтаж');

  const ServiceCategory(this.code, this.title);

  final String code;
  final String title;

  static ServiceCategory? fromCode(Object? code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// Услуга из прайс-листа. Связь с автомобилем — многие ко многим:
/// в заказе по машине несколько услуг, одна услуга встречается у многих.
class ServiceItem implements Entity {
  @override
  final int id;
  final String name;
  final ServiceCategory category;

  /// Цена в рублях.
  final int price;

  /// Норма времени в минутах.
  final int duration;
  @override
  final DateTime? deletedAt;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.duration,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  ServiceItem copyWith({
    int? id,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      name: name,
      category: category,
      price: price,
      duration: duration,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.code,
    'price': price,
    'duration': duration,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
    id: readInt(json, 'id'),
    name: readString(json, 'name'),
    category:
        ServiceCategory.fromCode(json['category']) ??
        ServiceCategory.maintenance,
    price: readInt(json, 'price'),
    duration: readInt(json, 'duration'),
    deletedAt: readDateOrNull(json, 'deletedAt'),
  );
}
