import '../models/entity_query.dart';
import '../models/service_item.dart';
import 'api_repository.dart';
import 'service_repository.dart';

/// Справочник: полный список кэшируется и не перезапрашивается
/// при каждом открытии формы автомобиля.
class ApiServiceRepository extends ApiRepository<ServiceItem, EntityQuery>
    implements ServiceRepository {
  ApiServiceRepository(super.dio, {required super.changes})
    : super(path: '/services', cacheAll: true);

  @override
  ServiceItem fromJson(Map<String, dynamic> json) => ServiceItem.fromJson(json);

  @override
  Map<String, Object> filterParameters(EntityQuery q) => {
    if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
    ...q.filters,
  };
}
