import '../models/entity_query.dart';
import '../models/brand.dart';
import 'api_repository.dart';
import 'brand_repository.dart';

/// Справочник: полный список кэшируется и не перезапрашивается
/// при каждом открытии формы автомобиля.
class ApiBrandRepository extends ApiRepository<Brand, EntityQuery>
    implements BrandRepository {
  ApiBrandRepository(super.dio, {required super.changes})
    : super(path: '/brands', cacheAll: true);

  @override
  Brand fromJson(Map<String, dynamic> json) => Brand.fromJson(json);

  @override
  Map<String, Object> filterParameters(EntityQuery q) => {
    if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
    ...q.filters,
  };
}
