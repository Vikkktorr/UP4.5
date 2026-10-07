/// Разбор параметров адреса.
///
/// Адрес пользователь может отредактировать вручную, поэтому любое значение
/// может оказаться мусором. Функции ниже не бросают исключений: некорректное
/// значение превращается в null, и вызывающий код подставляет умолчание.
library;

int? parseIntParam(String? raw) =>
    raw == null ? null : int.tryParse(raw.trim());

/// Номер страницы: целое не меньше единицы.
int parsePage(String? raw) {
  final value = parseIntParam(raw);
  return value == null || value < 1 ? 1 : value;
}

/// Допустимые размеры страницы. Любое другое значение из адреса
/// заменяется первым из списка.
const pageSizes = [10, 25, 50];

int parsePageSize(String? raw) {
  final value = parseIntParam(raw);
  return pageSizes.contains(value) ? value! : pageSizes.first;
}

/// Сортировка задаётся одним параметром: `sort=year,desc`.
/// Неизвестное поле заменяется [fallbackField].
({String field, bool ascending}) parseSort(
  String? raw, {
  required Set<String> allowed,
  required String fallbackField,
}) {
  if (raw == null || raw.isEmpty) {
    return (field: fallbackField, ascending: true);
  }
  final parts = raw.split(',');
  final field = allowed.contains(parts.first) ? parts.first : fallbackField;
  final ascending = parts.length < 2 || parts[1] != 'desc';
  return (field: field, ascending: ascending);
}

String formatSort(String field, bool ascending) =>
    ascending ? field : '$field,desc';

bool parseFlag(String? raw) => raw == '1' || raw == 'true';
