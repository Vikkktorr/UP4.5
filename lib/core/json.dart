/// Разбор значений из JSON, который не роняет приложение.
///
/// Данные приходят из внешнего источника — с сервера. Поля может не быть, оно может оказаться null или прийти
/// другого типа: число строкой, целое как 12.0. Каждая функция в таком
/// случае возвращает запасное значение, а не бросает исключение.
library;

int readInt(Map<String, dynamic> json, String key, [int fallback = 0]) =>
    asInt(json[key]) ?? fallback;

int? readIntOrNull(Map<String, dynamic> json, String key) => asInt(json[key]);

int? asInt(Object? value) => switch (value) {
  int v => v,
  double v when v == v.roundToDouble() => v.toInt(),
  String v => int.tryParse(v.trim()),
  _ => null,
};

String readString(
  Map<String, dynamic> json,
  String key, [
  String fallback = '',
]) => switch (json[key]) {
  String v => v,
  num v => '$v',
  _ => fallback,
};

/// Список идентификаторов. Нечисловые элементы отбрасываются, повторы тоже.
List<int> readIntList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return raw.map(asInt).whereType<int>().toSet().toList();
}

/// Идентификаторы из списка развёрнутых объектов: `[{"id": 1, …}, …]`.
List<int> readIdsOf(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => asInt(e['id']))
      .whereType<int>()
      .toSet()
      .toList();
}

List<String> readStringList(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

DateTime? readDateOrNull(Map<String, dynamic> json, String key) =>
    switch (json[key]) {
      String v => DateTime.tryParse(v),
      _ => null,
    };

DateTime readDate(Map<String, dynamic> json, String key, DateTime fallback) =>
    readDateOrNull(json, key) ?? fallback;

/// Вложенный объект; если его нет или это не объект — пустой.
Map<String, dynamic> readMap(Map<String, dynamic> json, String key) {
  final raw = json[key];
  return raw is Map ? raw.cast<String, dynamic>() : const {};
}

/// Дата без времени — так её удобно хранить и сравнивать.
String dateToJson(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
).toIso8601String().substring(0, 10);
