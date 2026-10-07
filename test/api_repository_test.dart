import 'dart:convert';
import 'dart:typed_data';

import 'package:autoservice_web/core/api_client.dart';
import 'package:autoservice_web/core/api_exceptions.dart';
import 'package:autoservice_web/models/car.dart';
import 'package:autoservice_web/models/car_query.dart';
import 'package:autoservice_web/models/fuel_type.dart';
import 'package:autoservice_web/repositories/api_brand_repository.dart';
import 'package:autoservice_web/repositories/api_car_repository.dart';
import 'package:autoservice_web/repositories/data_changes.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подменённый транспорт Dio: вместо сети отвечает заданная функция,
/// все запросы сохраняются для проверки.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.reply);

  final Future<ResponseBody> Function(RequestOptions options) reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

/// Сервер недоступен: так Dio сообщает об отказе в соединении.
Future<ResponseBody> unreachable(RequestOptions options) => Future.error(
  DioException.connectionError(
    requestOptions: options,
    reason: 'Connection refused',
  ),
);

final carJson = {
  'id': 1,
  'plate': 'А123ВС777',
  'vin': 'XTA219170K0123456',
  'brand': {'id': 1, 'name': 'Lada'},
  'model': 'Granta',
  'year': 2019,
  'mileage': 84500,
  'fuel': 'petrol',
  'client': {'id': 3, 'fullName': 'Иванов Сергей Петрович'},
  'mechanics': [
    {'id': 6, 'fullName': 'Титов И. А.'},
  ],
  'services': [
    {'id': 3, 'name': 'Замена масла'},
  ],
  'deletedAt': null,
};

const newCar = Car(
  id: 0,
  plate: 'А999АА77',
  vin: 'XTA219170K0123456',
  brandId: 1,
  model: 'Granta',
  year: 2020,
  mileage: 100,
  fuel: FuelType.petrol,
  clientId: 1,
  mechanicIds: [1],
  serviceIds: [1],
);

void main() {
  late FakeAdapter adapter;
  late DataChanges changes;

  Dio dioWith(Future<ResponseBody> Function(RequestOptions) reply) {
    adapter = FakeAdapter(reply);
    // Тот же клиент, что в приложении, но без пауз между повторами.
    return buildDio(retryDelay: Duration.zero)..httpClientAdapter = adapter;
  }

  setUp(() => changes = DataChanges());

  test(
    'find передаёт поиск, фильтры, сортировку и страницу серверу и разбирает оболочку',
    () async {
      final repo = ApiCarRepository(
        dioWith(
          (_) async => json(200, {
            'items': [carJson],
            'page': 2,
            'size': 10,
            'total': 11,
            'totalPages': 2,
          }),
        ),
        changes: changes,
      );

      final page = await repo.find(
        const CarQuery(
          search: ' kia ',
          brandId: 2,
          fuel: FuelType.diesel,
          sortField: 'year',
          sortAscending: false,
          page: 2,
        ),
      );

      final sent = adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.path, '/cars');
      expect(sent.queryParameters, {
        'search': 'kia',
        'brandId': 2,
        'fuel': 'diesel',
        'sort': 'year,desc',
        'page': 2,
        'size': 10,
      });
      expect(page.total, 11);
      expect(page.page, 2);
      // Развёрнутые объекты ответа превращаются в идентификаторы модели.
      final car = page.items.single;
      expect(car.brandId, 1);
      expect(car.clientId, 3);
      expect(car.mechanicIds, [6]);
      expect(car.serviceIds, [3]);
    },
  );

  test(
    'ответ 422 разбирается в ValidationException с ошибками по полям',
    () async {
      final repo = ApiCarRepository(
        dioWith(
          (_) async => json(422, {
            'message': 'Ошибка валидации',
            'errors': {'vin': 'VIN уже зарегистрирован (автомобиль №1)'},
          }),
        ),
        changes: changes,
      );

      await expectLater(
        repo.create(newCar),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['vin'],
            'errors[vin]',
            'VIN уже зарегистрирован (автомобиль №1)',
          ),
        ),
      );
      // В тело запроса уходят идентификаторы связей, без id и deletedAt.
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['brandId'], 1);
      expect(body['mechanicIds'], [1]);
      expect(body.containsKey('id'), isFalse);
    },
  );

  test('ответ 409 разбирается в ConflictException с текстом сервера', () async {
    final repo = ApiCarRepository(
      dioWith(
        (_) async => json(409, {
          'message':
              'У мастера Громов В. А. нет свободных мест: ведёт 2 автомобиля из 2',
        }),
      ),
      changes: changes,
    );

    await expectLater(
      repo.create(newCar),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.message,
          'message',
          contains('нет свободных мест'),
        ),
      ),
    );
  });

  test('недоступный сервер даёт NetworkException, а не DioException', () async {
    final repo = ApiCarRepository(dioWith(unreachable), changes: changes);

    await expectLater(repo.create(newCar), throwsA(isA<NetworkException>()));
    // Создание записи не повторяется: повтор мог бы создать дубль.
    expect(adapter.requests, hasLength(1));
  });

  test('чтение при сетевом сбое повторяется не больше трёх раз', () async {
    final repo = ApiCarRepository(dioWith(unreachable), changes: changes);

    await expectLater(
      repo.find(const CarQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests, hasLength(4)); // первая попытка и три повтора
  });

  test('после сбоя повтор получает данные', () async {
    var calls = 0;
    final repo = ApiCarRepository(
      dioWith((options) {
        calls++;
        return calls < 3
            ? unreachable(options)
            : Future.value(json(200, carJson));
      }),
      changes: changes,
    );

    final car = await repo.findById(1);
    expect(car?.plate, 'А123ВС777');
    expect(calls, 3);
  });

  test('404 в findById даёт null, 500 — ServerException', () async {
    final notFound = ApiCarRepository(
      dioWith((_) async => json(404, {'message': 'Объект не найден'})),
      changes: changes,
    );
    expect(await notFound.findById(99), isNull);

    final broken = ApiCarRepository(
      dioWith((_) async => json(500, {'message': 'Сбой'})),
      changes: changes,
    );
    await expectLater(
      broken.find(const CarQuery()),
      throwsA(isA<ServerException>()),
    );
  });

  test('справочник запрашивается один раз, после изменения — заново', () async {
    final repo = ApiBrandRepository(
      dioWith(
        (options) async => options.method == 'GET'
            ? json(200, {
                'items': [
                  {
                    'id': 1,
                    'name': 'Lada',
                    'country': 'Россия',
                    'models': ['Vesta'],
                  },
                ],
                'page': 1,
                'size': 100,
                'total': 1,
              })
            : json(204, null),
      ),
      changes: changes,
    );
    var notified = 0;
    changes.addListener(() => notified++);

    await repo.findAll();
    await repo.findAll();
    expect(adapter.requests, hasLength(1));

    await repo.softDelete(1);
    expect(notified, 1);
    await repo.findAll();
    expect(adapter.requests.where((r) => r.method == 'GET'), hasLength(2));
  });

  test('новый поиск отменяет предыдущий запрос', () async {
    final repo = ApiCarRepository(
      dioWith(
        (_) => Future.delayed(
          const Duration(milliseconds: 50),
          () => json(200, {'items': [], 'page': 1, 'size': 10, 'total': 0}),
        ),
      ),
      changes: changes,
    );

    final first = repo.find(const CarQuery(search: 'во'));
    final second = repo.find(const CarQuery(search: 'война'));

    await expectLater(
      first,
      throwsA(
        isA<NetworkException>().having(
          (e) => e.message,
          'message',
          'Запрос отменён.',
        ),
      ),
    );
    expect((await second).total, 0);
  });
}
