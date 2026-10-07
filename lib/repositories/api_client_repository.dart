import '../core/api_exceptions.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import 'api_repository.dart';
import 'client_repository.dart';

class ApiClientRepository extends ApiRepository<Client, ClientQuery>
    implements ClientRepository {
  ApiClientRepository(super.dio, {required super.changes})
    : super(path: '/clients');

  @override
  Client fromJson(Map<String, dynamic> json) => Client.fromJson(json);

  @override
  Future<Client> extendCard(int id) => guard(() async {
    final response = await dio.post<Map<String, dynamic>>(
      '$path/$id/extend-card',
    );
    return fromJson(response.data!);
  });

  @override
  Map<String, Object> filterParameters(ClientQuery q) => {
    if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
    if (q.level != null) 'level': q.level!.code,
  };
}
