import '../models/entity_query.dart';
import '../models/mechanic.dart';
import 'api_repository.dart';
import 'mechanic_repository.dart';

/// Справочник: полный список кэшируется и не перезапрашивается
/// при каждом открытии формы автомобиля.
class ApiMechanicRepository extends ApiRepository<Mechanic, EntityQuery>
    implements MechanicRepository {
  ApiMechanicRepository(super.dio, {required super.changes})
    : super(path: '/mechanics', cacheAll: true);

  @override
  Mechanic fromJson(Map<String, dynamic> json) => Mechanic.fromJson(json);

  @override
  Map<String, Object> filterParameters(EntityQuery q) => {
    if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
    ...q.filters,
  };
}
