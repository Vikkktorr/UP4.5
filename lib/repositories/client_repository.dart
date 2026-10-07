import '../models/client.dart';
import '../models/client_query.dart';
import 'entity_repository.dart';

abstract interface class ClientRepository
    implements EntityRepository<Client, ClientQuery> {
  /// Продление клубной карты на год. Сервер разрешает только владельцу.
  Future<Client> extendCard(int id);
}
