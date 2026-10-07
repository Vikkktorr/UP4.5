import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/brand.dart';
import '../models/car.dart';
import '../models/car_query.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import '../models/entity_query.dart';
import '../models/mechanic.dart';
import '../models/service_item.dart';
import '../models/with_cars.dart';
import '../repositories/brand_repository.dart';
import '../repositories/car_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/data_changes.dart';
import '../repositories/mechanic_repository.dart';
import '../repositories/service_repository.dart';
import '../screens/admin/stats_screen.dart';
import '../screens/admin/users_screen.dart';
import '../screens/auth/forbidden_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/car_detail_screen.dart';
import '../screens/car_list_screen.dart';
import '../screens/client_detail_screen.dart';
import '../screens/client_list_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/forms/car_form_screen.dart';
import '../screens/forms/client_form_screen.dart';
import '../screens/forms/reference_form_screens.dart';
import '../screens/my_cars_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/reference_screens.dart';
import '../state/auth_notifier.dart';
import '../state/detail_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/entity_form/leave_guard.dart';
import 'permissions.dart';

/// Маршруты приложения. У каждой из пяти сущностей одинаковый набор:
///
///   /cars            список
///   /cars/new        форма создания
///   /cars/:id        карточка
///   /cars/:id/edit   форма изменения — тот же экран, что и создание
///
/// Доступ проверяется в redirect: общий — «вошёл ли пользователь»,
/// у веток — «разрешено ли его роли». Это удобство интерфейса, а не
/// защита: настоящую проверку выполняет сервер.
GoRouter createRouter({
  required AuthNotifier auth,
  String initialLocation = '/',
  required LeaveGuard guard,
}) {
  // Проверка роли на уровне ветки маршрутов: чужой адрес, открытый
  // вручную, ведёт на экран отказа.
  GoRouterRedirect allow(Operation operation) =>
      (context, state) => auth.can(operation) ? null : '/forbidden';

  // Уход с формы (боковое меню, ссылка, кнопка «назад» браузера)
  // сначала спрашивает форму, нет ли несохранённых изменений.
  Future<bool> onExit(BuildContext context, GoRouterState state) =>
      guard.canLeave();

  List<RouteBase> entityRoutes({
    required Widget Function(GoRouterState state) form,
    required Widget Function(int id) edit,
    required Widget Function(BuildContext context, int id) detail,
  }) => [
    // «new» объявлен раньше «:id», иначе адрес /cars/new разобрался бы
    // как карточка с идентификатором «new».
    GoRoute(
      path: 'new',
      onExit: onExit,
      redirect: allow(Operation.editRecords),
      builder: (context, state) => form(state),
    ),
    GoRoute(
      path: ':id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id']!);
        if (id == null) return NotFoundScreen(location: state.uri.toString());
        return detail(context, id);
      },
      routes: [
        GoRoute(
          path: 'edit',
          onExit: onExit,
          redirect: allow(Operation.editRecords),
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id']!);
            if (id == null) {
              return NotFoundScreen(location: state.uri.toString());
            }
            // Ключ по id: при переходе с одной формы на другую экран
            // создаётся заново и загружает свою запись.
            return KeyedSubtree(key: ValueKey('edit-$id'), child: edit(id));
          },
        ),
      ],
    ),
  ];

  return GoRouter(
    initialLocation: initialLocation,
    // Маршрутизатор пересчитает redirect при каждом notifyListeners():
    // после входа уйдёт с формы входа, после выхода — на неё.
    refreshListenable: auth,
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final target = state.matchedLocation;
      final isPublic = target == '/login' || target == '/register';

      // Не вошёл и идёт на закрытый экран — на вход,
      // запомнив адрес, куда он хотел попасть
      if (!loggedIn && !isPublic) {
        final from = state.uri.toString();
        return from == '/'
            ? '/login'
            : '/login?from=${Uri.encodeComponent(from)}';
      }

      // Уже вошёл и идёт на экран входа — туда, откуда его отправили
      // на вход, либо на главную
      if (loggedIn && isPublic) {
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') ? from : '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/forbidden',
            builder: (context, state) => const ForbiddenScreen(),
          ),
          // Личные экраны: у каждой роли свой.
          GoRoute(
            path: '/my',
            redirect: allow(Operation.viewOwnCars),
            builder: (context, state) => auth.user == null
                ? const SizedBox.shrink()
                : MyCarsScreen.client(auth.user!),
          ),
          GoRoute(
            path: '/work',
            redirect: allow(Operation.viewOwnWork),
            builder: (context, state) => auth.user == null
                ? const SizedBox.shrink()
                : MyCarsScreen.mechanic(auth.user!),
          ),
          GoRoute(
            path: '/admin/users',
            redirect: allow(Operation.manageUsers),
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/admin/stats',
            redirect: allow(Operation.viewStats),
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/cars',
            redirect: allow(Operation.viewWorkshop),
            // Условия отбора берутся из адреса — аналог @RequestParam.
            builder: (context, state) => CarListScreen(
              query: CarQuery.fromQueryParameters(state.uri.queryParameters),
            ),
            routes: entityRoutes(
              form: (_) => const CarFormScreen(),
              edit: (id) => CarFormScreen(id: id),
              detail: (context, id) => _detail<Car>(
                'car-$id',
                context,
                () => context.read<CarRepository>().findById(id),
                CarDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            path: '/clients',
            redirect: allow(Operation.viewWorkshop),
            builder: (context, state) => ClientListScreen(
              query: ClientQuery.fromQueryParameters(state.uri.queryParameters),
            ),
            routes: entityRoutes(
              form: (_) => const ClientFormScreen(),
              edit: (id) => ClientFormScreen(id: id),
              detail: (context, id) => _detail<WithCars<Client>>(
                'client-$id',
                context,
                () => _withCars(
                  context,
                  context.read<ClientRepository>().findById(id),
                  CarQuery(clientId: id, size: 50),
                ),
                ClientDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            path: '/brands',
            redirect: allow(Operation.viewWorkshop),
            builder: (context, state) => BrandListScreen(
              query: EntityQuery.fromQueryParameters(
                Queries.brands,
                state.uri.queryParameters,
              ),
            ),
            routes: entityRoutes(
              form: (_) => const BrandFormScreen(),
              edit: (id) => BrandFormScreen(id: id),
              detail: (context, id) => _detail<WithCars<Brand>>(
                'brand-$id',
                context,
                () => _withCars(
                  context,
                  context.read<BrandRepository>().findById(id),
                  CarQuery(brandId: id, size: 20),
                ),
                BrandDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            path: '/mechanics',
            redirect: allow(Operation.viewWorkshop),
            builder: (context, state) => MechanicListScreen(
              query: EntityQuery.fromQueryParameters(
                Queries.mechanics,
                state.uri.queryParameters,
              ),
            ),
            routes: entityRoutes(
              form: (_) => const MechanicFormScreen(),
              edit: (id) => MechanicFormScreen(id: id),
              detail: (context, id) => _detail<WithCars<Mechanic>>(
                'mechanic-$id',
                context,
                () => _withCars(
                  context,
                  context.read<MechanicRepository>().findById(id),
                  CarQuery(mechanicId: id, size: 20),
                ),
                MechanicDetailScreen(id: id),
              ),
            ),
          ),
          GoRoute(
            // Каталог услуг открыт всем ролям; формы — только мастеру
            // и администратору (redirect у new и edit).
            path: '/services',
            redirect: allow(Operation.viewCatalog),
            builder: (context, state) => ServiceListScreen(
              query: EntityQuery.fromQueryParameters(
                Queries.services,
                state.uri.queryParameters,
              ),
            ),
            routes: entityRoutes(
              form: (_) => const ServiceFormScreen(),
              edit: (id) => ServiceFormScreen(id: id),
              detail: (context, id) => _detail<WithCars<ServiceItem>>(
                'service-$id',
                context,
                () => _withCars(
                  context,
                  context.read<ServiceRepository>().findById(id),
                  CarQuery(serviceId: id, size: 20),
                  withCars: auth.has(Role.mechanic),
                ),
                ServiceDetailScreen(id: id),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Состояние карточки живёт, пока открыт экран. После изменений на
/// сервере (сохранили форму, удалили связанную запись) карточка
/// перечитывается сама.
Widget _detail<T>(
  String key,
  BuildContext context,
  Future<T?> Function() loader,
  Widget child,
) => ChangeNotifierProvider(
  key: ValueKey(key),
  create: (context) =>
      DetailNotifier<T>(loader, changes: context.read<DataChanges>())..load(),
  child: child,
);

Future<WithCars<T>?> _withCars<T>(
  BuildContext context,
  Future<T?> item,
  CarQuery query, {
  bool withCars = true,
}) async {
  final cars = context.read<CarRepository>();
  final found = await item;
  if (found == null) return null;
  if (!withCars) return WithCars(item: found, cars: const [], total: 0);
  final page = await cars.find(query);
  return WithCars(item: found, cars: page.items, total: page.total);
}
