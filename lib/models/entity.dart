/// Общее у всех записей: идентификатор, отметка логического удаления
/// и преобразование в JSON для хранилища.
abstract interface class Entity {
  int get id;
  DateTime? get deletedAt;
  bool get isDeleted;
  Map<String, dynamic> toJson();
}

/// Общее у всех объектов условий отбора — то, что нужно репозиторию,
/// чтобы вырезать страницу и учесть удалённые записи.
abstract interface class PagedQuery {
  int get page;
  int get size;
  bool get includeDeleted;
  String get sortField;
  bool get sortAscending;
}
