import '../models/car.dart';
import '../models/car_query.dart';
import 'api_repository.dart';
import 'car_repository.dart';

class ApiCarRepository extends ApiRepository<Car, CarQuery>
    implements CarRepository {
  ApiCarRepository(super.dio, {required super.changes}) : super(path: '/cars');

  @override
  Car fromJson(Map<String, dynamic> json) => Car.fromJson(json);

  /// Поиск, фильтры, сортировка и страницы выполняются на сервере:
  /// клиент хранит только текущую страницу.
  @override
  Map<String, Object> filterParameters(CarQuery q) => {
    if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
    if (q.brandId != null) 'brandId': q.brandId!,
    if (q.fuel != null) 'fuel': q.fuel!.code,
    if (q.yearFrom != null) 'yearFrom': q.yearFrom!,
    if (q.yearTo != null) 'yearTo': q.yearTo!,
    if (q.clientId != null) 'clientId': q.clientId!,
    if (q.mechanicId != null) 'mechanicId': q.mechanicId!,
    if (q.serviceId != null) 'serviceId': q.serviceId!,
  };
}
