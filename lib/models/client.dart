import '../core/json.dart';
import 'club_card.dart';
import 'entity.dart';

/// Клиент автосервиса — владелец одного или нескольких автомобилей.
class Client implements Entity {
  @override
  final int id;
  final String lastName;
  final String firstName;
  final String middleName;

  /// Телефон в виде «+7 (916) 123-45-67».
  final String phone;
  final String email;

  /// Персональная скидка на работы, в процентах.
  final int discount;
  final DateTime registeredAt;

  /// Клубная карта — связь «один к одному».
  final ClubCard card;
  @override
  final DateTime? deletedAt;

  const Client({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.middleName = '',
    required this.phone,
    required this.email,
    this.discount = 0,
    required this.registeredAt,
    required this.card,
    this.deletedAt,
  });

  @override
  bool get isDeleted => deletedAt != null;

  String get fullName =>
      [lastName, firstName, middleName].where((s) => s.isNotEmpty).join(' ');

  /// «Иванов И. П.» — для колонок таблицы и выпадающих списков.
  String get shortName {
    final initials = [
      firstName,
      middleName,
    ].where((s) => s.isNotEmpty).map((s) => '${s[0]}.').join(' ');
    return initials.isEmpty ? lastName : '$lastName $initials';
  }

  Client copyWith({
    int? id,
    String? lastName,
    String? firstName,
    String? middleName,
    String? phone,
    String? email,
    int? discount,
    DateTime? registeredAt,
    ClubCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Client(
      id: id ?? this.id,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      discount: discount ?? this.discount,
      registeredAt: registeredAt ?? this.registeredAt,
      card: card ?? this.card,
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
    'email': email,
    'discount': discount,
    'registeredAt': dateToJson(registeredAt),
    'card': card.toJson(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Client.fromJson(Map<String, dynamic> json) {
    final registered = readDate(json, 'registeredAt', DateTime(2000));
    return Client(
      id: readInt(json, 'id'),
      lastName: readString(json, 'lastName'),
      firstName: readString(json, 'firstName'),
      middleName: readString(json, 'middleName'),
      phone: readString(json, 'phone'),
      email: readString(json, 'email'),
      discount: readInt(json, 'discount'),
      registeredAt: registered,
      // Вложенный объект разбирается своим fromJson. Если карты в данных
      // нет, поля получат умолчания, а дата выдачи — дату регистрации.
      card: ClubCard.fromJson({
        'issuedAt': dateToJson(registered),
        ...readMap(json, 'card'),
      }),
      deletedAt: readDateOrNull(json, 'deletedAt'),
    );
  }
}
