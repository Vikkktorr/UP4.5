/// Роли пользователей. Уровень задаёт старшинство: мастеру доступно всё,
/// что клиенту в каталоге, администратору — всё, что мастеру.
enum Role {
  client(1, 'Клиент'),
  mechanic(2, 'Мастер'),
  admin(3, 'Администратор');

  const Role(this.level, this.title);

  final int level;
  final String title;

  static Role fromName(String? name) =>
      Role.values.firstWhere((r) => r.name == name, orElse: () => Role.client);
}

/// Вошедший пользователь, как его описывает сервер.
///
/// [clientId] и [mechanicId] связывают учётную запись с записью клиента
/// или мастера: по ним строятся экраны «Мои автомобили» и «Мои работы».
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.lastName,
    required this.firstName,
    this.clientId,
    this.mechanicId,
  });

  final int id;
  final String username;
  final Role role;
  final String lastName;
  final String firstName;
  final int? clientId;
  final int? mechanicId;

  String get fullName => '$lastName $firstName'.trim();

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    username: json['username'] as String,
    role: Role.fromName(json['role'] as String?),
    lastName: json['lastName'] as String? ?? '',
    firstName: json['firstName'] as String? ?? '',
    clientId: json['clientId'] as int?,
    mechanicId: json['mechanicId'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'role': role.name,
    'lastName': lastName,
    'firstName': firstName,
    'clientId': clientId,
    'mechanicId': mechanicId,
  };
}
