import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../core/permissions.dart';
import '../models/car.dart';
import '../state/car_list_notifier.dart';
import '../state/auth_notifier.dart';
import '../state/detail_notifier.dart';
import '../state/lookup_notifier.dart';
import '../widgets/detail_view.dart';
import '../widgets/list_toolbar.dart';

/// Карточка автомобиля: /cars/:id. Показывает все четыре связи:
/// марку и владельца (многие к одному), мастеров и услуги (многие ко многим).
class CarDetailScreen extends StatelessWidget {
  const CarDetailScreen({super.key, required this.id});

  final int id;

  /// Возврат к списку с теми же условиями отбора, с которыми его покинули.
  void _back(BuildContext context) =>
      context.go(context.read<CarListNotifier>().query.toLocation());

  Future<void> _act(
    BuildContext context,
    Future<void> Function(int id) action,
    String done,
  ) async {
    final detail = context.read<DetailNotifier<Car>>();
    try {
      await action(id);
      if (!context.mounted) return;
      showMessage(context, done);
      await detail.load();
    } catch (e) {
      if (context.mounted) showMessage(context, '$e');
    }
  }

  Future<void> _hardDelete(BuildContext context, Car car) async {
    final list = context.read<CarListNotifier>();
    final ok = await confirmAction(
      context,
      title: 'Удалить навсегда?',
      message:
          'Автомобиль ${car.plate} будет стёрт без возможности '
          'восстановления.',
      confirmLabel: 'Удалить навсегда',
    );
    if (!ok || !context.mounted) return;
    try {
      await list.hardDelete(car.id);
      if (!context.mounted) return;
      showMessage(context, 'Автомобиль ${car.plate} стёрт');
      _back(context);
    } catch (e) {
      if (context.mounted) showMessage(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final detail = context.watch<DetailNotifier<Car>>();
    final lookup = context.watch<LookupNotifier>();
    final list = context.read<CarListNotifier>();

    return Title(
      title: 'Автомобиль — Автосервис',
      color: Theme.of(context).colorScheme.primary,
      child: DetailStateView<Car>(
        state: detail.state,
        onRetry: detail.load,
        onBack: () => _back(context),
        notFoundText: 'Автомобиль №$id не найден',
        builder: (car) {
          final theme = Theme.of(context);
          final brand = lookup.brand(car.brandId);
          final services = [
            for (final sid in car.serviceIds) ?lookup.service(sid),
          ];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => _back(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('К списку автомобилей'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(car.plate, style: theme.textTheme.headlineMedium),
                    Text(
                      '${brand?.name ?? ''} ${car.model}',
                      style: theme.textTheme.titleLarge,
                    ),
                    if (car.isDeleted) const DeletedBadge(),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        InfoTile(label: 'VIN', value: SelectableText(car.vin)),
                        InfoTile(
                          label: 'Марка',
                          value: LinkText(
                            brand == null
                                ? '—'
                                : '${brand.name} (${brand.country})',
                            onTap: () => context.go('/brands/${car.brandId}'),
                          ),
                        ),
                        InfoTile(label: 'Модель', value: Text(car.model)),
                        InfoTile(
                          label: 'Год выпуска',
                          value: Text('${car.year}'),
                        ),
                        InfoTile(
                          label: 'Пробег',
                          value: Text(formatMileage(car.mileage)),
                        ),
                        InfoTile(
                          label: 'Двигатель',
                          value: Text(car.fuel.title),
                        ),
                        InfoTile(
                          label: 'Владелец',
                          value: LinkText(
                            lookup.client(car.clientId)?.fullName ??
                                'Клиент #${car.clientId}',
                            onTap: () => context.go('/clients/${car.clientId}'),
                          ),
                        ),
                        if (car.deletedAt != null)
                          InfoTile(
                            label: 'Удалён',
                            value: Text(formatDate(car.deletedAt!)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle('Мастера (${car.mechanicIds.length})'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mid in car.mechanicIds)
                      ActionChip(
                        avatar: const Icon(
                          Icons.engineering_outlined,
                          size: 18,
                        ),
                        label: Text(
                          lookup.mechanic(mid) == null
                              ? 'Мастер #$mid'
                              : '${lookup.mechanicName(mid)} · '
                                    '${lookup.mechanic(mid)!.grade} разряд',
                        ),
                        onPressed: () => context.go('/mechanics/$mid'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionTitle('Услуги в заказе (${services.length})'),
                Card(
                  child: Column(
                    children: [
                      for (final s in services)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.build_outlined),
                          title: Text(s.name),
                          subtitle: Text(
                            '${s.category.title} · ${formatDuration(s.duration)}',
                          ),
                          trailing: Text(formatMoney(s.price)),
                          onTap: () => context.go('/services/${s.id}'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: car.isDeleted
                      ? [
                          if (auth.can(Operation.restore))
                            FilledButton.icon(
                              onPressed: () => _act(
                                context,
                                list.restore,
                                'Автомобиль восстановлен',
                              ),
                              icon: const Icon(Icons.restore_from_trash),
                              label: const Text('Восстановить'),
                            ),
                          if (auth.can(Operation.hardDelete))
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                              onPressed: () => _hardDelete(context, car),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Удалить навсегда'),
                            ),
                        ]
                      : [
                          FilledButton.icon(
                            onPressed: () => context.go('/cars/${car.id}/edit'),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Изменить'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _act(
                              context,
                              list.softDelete,
                              'Автомобиль удалён',
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Удалить'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.go('/cars?clientId=${car.clientId}'),
                            icon: const Icon(Icons.garage_outlined),
                            label: const Text('Все автомобили владельца'),
                          ),
                        ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
