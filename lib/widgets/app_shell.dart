import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../repositories/network_simulator.dart';
import '../state/auth_notifier.dart';

/// Разделы приложения и операция, которая нужна, чтобы раздел увидеть.
/// Раздел, недоступный роли, не попадает ни в меню, ни на главную —
/// а открытый вручную адрес остановит redirect маршрута.
const appSections = [
  (
    title: 'Главная',
    path: '/',
    icon: Icons.home_outlined,
    operation: null,
    about: '',
  ),
  (
    title: 'Мои автомобили',
    path: '/my',
    icon: Icons.garage_outlined,
    operation: Operation.viewOwnCars,
    about: 'Ваши автомобили, услуги и клубная карта',
  ),
  (
    title: 'Мои работы',
    path: '/work',
    icon: Icons.handyman_outlined,
    operation: Operation.viewOwnWork,
    about: 'Автомобили, закреплённые за вами',
  ),
  (
    title: 'Автомобили',
    path: '/cars',
    icon: Icons.directions_car_outlined,
    operation: Operation.viewWorkshop,
    about: 'Учёт автомобилей, назначение мастеров и услуг',
  ),
  (
    title: 'Клиенты',
    path: '/clients',
    icon: Icons.people_outline,
    operation: Operation.viewWorkshop,
    about: 'Клиенты и клубные карты',
  ),
  (
    title: 'Марки',
    path: '/brands',
    icon: Icons.sell_outlined,
    operation: Operation.viewWorkshop,
    about: 'Справочник марок и моделей',
  ),
  (
    title: 'Мастера',
    path: '/mechanics',
    icon: Icons.engineering_outlined,
    operation: Operation.viewWorkshop,
    about: 'Мастера, разряды, места в графике',
  ),
  (
    title: 'Услуги',
    path: '/services',
    icon: Icons.build_outlined,
    operation: Operation.viewCatalog,
    about: 'Каталог услуг и цены',
  ),
  (
    title: 'Пользователи',
    path: '/admin/users',
    icon: Icons.manage_accounts_outlined,
    operation: Operation.manageUsers,
    about: 'Учётные записи и роли',
  ),
  (
    title: 'Статистика',
    path: '/admin/stats',
    icon: Icons.bar_chart_outlined,
    operation: Operation.viewStats,
    about: 'Сводка по данным автосервиса',
  ),
];

/// Общий каркас экранов с адаптивной навигацией.
///
/// Узкое окно — нижняя панель, как на телефоне; среднее — боковая полоса
/// со значками; широкое — раскрытая полоса с подписями.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final auth = context.watch<AuthNotifier>();
    // Условное построение меню по роли — аналог sec:authorize в шаблоне.
    final sections = [
      for (final s in appSections)
        if (s.operation == null || auth.can(s.operation!)) s,
    ];
    final location = GoRouterState.of(context).uri.path;
    final selected = sections.indexWhere(
      (s) =>
          location == s.path ||
          (s.path != '/' && location.startsWith('${s.path}/')),
    );
    void onSelect(int index) => context.go(sections[index].path);

    if (size == ScreenSize.compact) {
      return Scaffold(
        appBar: AppBar(
          title: const _Logo(),
          actions: const [_UserMenu(), _NetworkMenu()],
        ),
        body: _Content(child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected < 0 ? 0 : selected,
          onDestinationSelected: onSelect,
          destinations: [
            for (final s in sections)
              NavigationDestination(icon: Icon(s.icon), label: s.title),
          ],
        ),
      );
    }

    final extended = size == ScreenSize.expanded;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected < 0 ? null : selected,
            onDestinationSelected: onSelect,
            extended: extended,
            // extended и labelType, отличный от none, вместе задавать нельзя.
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: extended
                  ? const _Logo()
                  : Icon(
                      Icons.car_repair,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
            trailing: const Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: _NetworkMenu(),
                ),
              ),
            ),
            destinations: [
              for (final s in sections)
                NavigationRailDestination(
                  icon: Icon(s.icon),
                  label: Text(s.title),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                // Шапка с именем вошедшего пользователя и кнопкой выхода.
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 16, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _UserMenu(),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _Content(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.car_repair, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('Автосервис', style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// Имя и роль пользователя в шапке, кнопка выхода.
class _UserMenu extends StatelessWidget {
  const _UserMenu();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final compact = screenSizeOf(context) == ScreenSize.compact;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            user.firstName.isEmpty ? '?' : user.firstName[0],
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: 8),
        // Имя показывается всегда; на узком экране — без роли.
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.fullName, style: theme.textTheme.titleSmall),
            if (!compact)
              Text(
                user.role.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        SizedBox(width: compact ? 4 : 16),
        IconButton(
          tooltip: 'Выйти',
          icon: const Icon(Icons.logout),
          // Токены удаляются, redirect отправит на экран входа.
          onPressed: auth.logout,
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = screenSizeOf(context) == ScreenSize.compact;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.contentMaxWidth,
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 24),
          child: child,
        ),
      ),
    );
  }
}

/// Меню отладки: учебные параметры сервера ?__fail=500 и ?__delay=1500,
/// чтобы принудительно проверить экраны ошибки и загрузки.
class _NetworkMenu extends StatelessWidget {
  const _NetworkMenu();

  @override
  Widget build(BuildContext context) {
    final net = context.watch<NetworkSimulator>();
    return PopupMenuButton<void>(
      tooltip: 'Отладка',
      icon: Icon(
        net.failing
            ? Icons.wifi_off
            : net.slow
            ? Icons.hourglass_bottom
            : Icons.bug_report_outlined,
        color: net.failing ? Theme.of(context).colorScheme.error : null,
      ),
      itemBuilder: (context) => [
        CheckedPopupMenuItem<void>(
          checked: net.failing,
          onTap: () => net.failing = !net.failing,
          child: const Text('Ошибка сервера 500'),
        ),
        CheckedPopupMenuItem<void>(
          checked: net.slow,
          onTap: () => net.slow = !net.slow,
          child: const Text('Задержка ответа 1,5 с'),
        ),
      ],
    );
  }
}
