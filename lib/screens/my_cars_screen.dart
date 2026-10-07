import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../models/car.dart';
import '../models/car_query.dart';
import '../models/client.dart';
import '../repositories/car_repository.dart';
import '../repositories/client_repository.dart';
import '../state/auth_notifier.dart';
import '../state/lookup_notifier.dart';
import '../widgets/list_toolbar.dart';

/// Личные экраны: «Мои автомобили» клиента (/my) и «Мои работы»
/// мастера (/work). Каждый доступен ровно одной роли.
///
/// Сервер отдаёт клиенту только автомобили с его clientId — запрос
/// с чужим clientId получит 403.
class MyCarsScreen extends StatefulWidget {
  MyCarsScreen.client(AppUser user, {super.key})
    : title = 'Мои автомобили',
      hint = 'Автомобили, которые обслуживаются в автосервисе.',
      empty = 'За вашей учётной записью пока нет автомобилей.',
      unlinked =
          'Учётная запись не связана с карточкой клиента автосервиса. '
          'Обратитесь к администратору.',
      linkedId = user.clientId,
      forMechanic = false;

  MyCarsScreen.mechanic(AppUser user, {super.key})
    : title = 'Мои работы',
      hint = 'Автомобили, закреплённые за вами как за мастером.',
      empty = 'Сейчас за вами не закреплено ни одного автомобиля.',
      unlinked = 'Учётная запись не связана с карточкой мастера.',
      linkedId = user.mechanicId,
      forMechanic = true;

  final String title;
  final String hint;
  final String empty;
  final String unlinked;
  final int? linkedId;
  final bool forMechanic;

  @override
  State<MyCarsScreen> createState() => _MyCarsScreenState();
}

class _MyCarsScreenState extends State<MyCarsScreen> {
  Future<List<Car>>? _cars;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final id = widget.linkedId;
    if (id == null) return;
    final query = widget.forMechanic
        ? CarQuery(mechanicId: id, size: 50)
        : CarQuery(clientId: id, size: 50);
    setState(() {
      _cars = context
          .read<CarRepository>()
          .find(query)
          .then((page) => page.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookup = context.watch<LookupNotifier>();

    return Title(
      title: '${widget.title} — Автосервис',
      color: theme.colorScheme.primary,
      child: ListView(
        children: [
          Text(widget.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            widget.hint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (!widget.forMechanic && widget.linkedId != null) ...[
            _ClubCardPanel(clientId: widget.linkedId!),
            const SizedBox(height: 16),
          ],
          if (_cars == null)
            Text(widget.unlinked)
          else
            FutureBuilder<List<Car>>(
              future: _cars,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final cars = snapshot.data!;
                if (cars.isEmpty) return Text(widget.empty);
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final car in cars)
                      SizedBox(
                        width: 360,
                        child: _CarCard(
                          car: car,
                          lookup: lookup,
                          forMechanic: widget.forMechanic,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.car,
    required this.lookup,
    required this.forMechanic,
  });

  final Car car;
  final LookupNotifier lookup;
  final bool forMechanic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = car.serviceIds.fold<int>(
      0,
      (sum, id) => sum + (lookup.service(id)?.price ?? 0),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Мастер может открыть карточку автомобиля; клиенту она недоступна.
        onTap: forMechanic ? () => context.go('/cars/${car.id}') : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_car_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${lookup.brandName(car.brandId)} ${car.model}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(car.plate, style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${car.year} г. · ${formatMileage(car.mileage)}'
                '${forMechanic ? ' · ${lookup.clientName(car.clientId)}' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in car.serviceIds)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(lookup.serviceName(id)),
                    ),
                ],
              ),
              if (price > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Стоимость услуг: ${formatMoney(price)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Клубная карта клиента и продление её срока на год.
class _ClubCardPanel extends StatefulWidget {
  const _ClubCardPanel({required this.clientId});

  final int clientId;

  @override
  State<_ClubCardPanel> createState() => _ClubCardPanelState();
}

class _ClubCardPanelState extends State<_ClubCardPanel> {
  Client? _client;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<ClientRepository>().findById(widget.clientId).then((c) {
      if (mounted) setState(() => _client = c);
    }, onError: (_) {});
  }

  Future<void> _extend() async {
    setState(() => _busy = true);
    try {
      final client = await context.read<ClientRepository>().extendCard(
        widget.clientId,
      );
      if (!mounted) return;
      setState(() => _client = client);
      showMessage(
        context,
        'Карта продлена до ${formatDate(client.card.expiresAt)}',
      );
    } catch (e) {
      // 403, если операцию запросил не владелец карты.
      if (mounted) showMessage(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = _client?.card;
    if (card == null) return const SizedBox.shrink();
    final expired = card.isExpiredAt(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.card_membership_outlined),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Клубная карта ${card.number} · ${card.level.title}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${expired ? 'Истекла' : 'Действует до'} '
                  '${formatDate(card.expiresAt)} · бонусов: ${card.bonusPoints}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: expired
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (context.watch<AuthNotifier>().can(Operation.extendOwnCard))
              FilledButton.icon(
                onPressed: _busy ? null : _extend,
                icon: const Icon(Icons.update),
                label: const Text('Продлить на год'),
              ),
          ],
        ),
      ),
    );
  }
}
