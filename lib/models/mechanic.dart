import '../core/json.dart';
import 'entity.dart';

/// Мастер автосервиса. Связь с автомобилем — многие ко многим: за
/// автомобилем закреплено несколько мастеров, мастер ведёт много машин.
class Mechanic implements Entity {
  @override
  final int id;
  final String lastName;
  final String firstName;
  final String middleName;
  final String phone;

  /// Квалификационный разряд, 1–6.
  final int grade;

  /// Стаж в годах.
  final int experience;

  /// Мест в графике: сколько автомобилей мастер ведёт одновременно.
  /// Если все места заняты, записать к нему автомобиль нельзя (409).
  final int capacity;
  final DateTime hiredAt;
  @override
  final DateTime? deletedAt;

  const Mechanic({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.middleName = '',
    required this.phone,
    required this.grade,
    required this.experience,
    this.capacity = 5,
    required this.hiredAt,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  String get fullName =>
      [lastName, firstName, middleName].where((s) => s.isNotEmpty).join(' ');

  String get shortName {
    final initials = [
      firstName,
      middleName,
    ].where((s) => s.isNotEmpty).map((s) => '${s[0]}.').join(' ');
    return initials.isEmpty ? lastName : '$lastName $initials';
  }

  Mechanic copyWith({
    int? id,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Mechanic(
      id: id ?? this.id,
      lastName: lastName,
      firstName: firstName,
      middleName: middleName,
      phone: phone,
      grade: grade,
      experience: experience,
      capacity: capacity,
      hiredAt: hiredAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'lastName': lastName,
    'firstName': firstName,
    'middleName': middleName,
    'phone': phone,
    'grade': grade,
    'experience': experience,
    'capacity': capacity,
    'hiredAt': dateToJson(hiredAt),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Mechanic.fromJson(Map<String, dynamic> json) => Mechanic(
    id: readInt(json, 'id'),
    lastName: readString(json, 'lastName'),
    firstName: readString(json, 'firstName'),
    middleName: readString(json, 'middleName'),
    phone: readString(json, 'phone'),
    grade: readInt(json, 'grade', 1),
    experience: readInt(json, 'experience'),
    capacity: readInt(json, 'capacity', 5),
    hiredAt: readDate(json, 'hiredAt', DateTime(2000)),
    deletedAt: readDateOrNull(json, 'deletedAt'),
  );
}
