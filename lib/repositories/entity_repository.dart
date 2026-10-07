import '../models/page_result.dart';

/// Что приложение умеет делать с записями списка — безотносительно того,
/// где они хранятся.
///
/// [T] — модель, [Q] — объект условий отбора. Общий интерфейс позволяет
/// написать одно состояние списка на все сущности.
abstract interface class EntityRepository<T, Q> {
  Future<PageResult<T>> find(Q query);

  /// Все записи, включая удалённые, — для подписей и выпадающих списков.
  Future<List<T>> findAll();
  Future<T?> findById(int id);

  /// Ошибки проверки на сервере — [ValidationException] с ошибками по полям,
  /// нарушение ограничений целостности — [ConflictException].
  Future<T> create(T entity);
  Future<T> update(T entity);

  /// Логическое удаление: запись получает deletedAt и пропадает из выборки.
  Future<void> softDelete(int id);

  /// Физическое удаление: запись стирается насовсем.
  Future<void> hardDelete(int id);
  Future<void> restore(int id);

  /// Логически удаляет несколько записей, возвращает число удалённых.
  Future<int> deleteMany(List<int> ids);
}
