import '../core/json.dart';
import 'entity.dart';

/// Марка автомобиля — справочник, на который ссылается [Car.brandId].
///
/// Связь с автомобилем — один ко многим: у марки много автомобилей,
/// у автомобиля одна марка. [models] задаёт допустимые модели и сужает
/// выбор модели в форме автомобиля.
class Brand implements Entity {
  @override
  final int id;
  final String name;
  final String country;
  final List<String> models;
  @override
  final DateTime? deletedAt;

  const Brand({
    required this.id,
    required this.name,
    required this.country,
    this.models = const [],
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  Brand copyWith({
    int? id,
    String? name,
    String? country,
    List<String>? models,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Brand(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      models: models ?? this.models,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'models': models,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    id: readInt(json, 'id'),
    name: readString(json, 'name'),
    country: readString(json, 'country'),
    models: readStringList(json, 'models'),
    deletedAt: readDateOrNull(json, 'deletedAt'),
  );
}
