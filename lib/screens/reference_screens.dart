import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/brand.dart';
import '../models/entity_query.dart';
import '../models/mechanic.dart';
import '../models/service_item.dart';
import '../state/lookup_notifier.dart';
import '../state/reference_list_notifiers.dart';
import '../widgets/detail_view.dart';
import '../widgets/entity_form/form_spec.dart';
import '../widgets/entity_table.dart';
import 'reference_detail_screen.dart';
import 'reference_list_screen.dart';

/// Списки и карточки трёх справочников — настройки общих экранов.

// ---- марки ----

class BrandListScreen extends StatelessWidget {
  const BrandListScreen({super.key, required this.query});

  final EntityQuery query;

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupNotifier>();
    return ReferenceListScreen<Brand, BrandListNotifier>(
      query: query,
      title: 'Марки',
      addLabel: 'Добавить марку',
      searchHint: 'Марка или модель',
      sortLabels: const {
        'name': 'Название',
        'country': 'Страна',
        'models': 'Число моделей',
      },
      filters: [
        ListFilter(
          key: 'country',
          label: 'Страна',
          allLabel: 'Все страны',
          options: [for (final c in lookup.countries) Option(c, c)],
        ),
      ],
      nouns: ('марка', 'марки', 'марок'),
      labelOf: (b) => b.name,
      cardTitle: (b) => b.name,
      cardSubtitle: (b) => '${b.country} · моделей: ${b.models.length}',
      columns: [
        nameColumn<Brand>('Марка', (b) => b.name, sortField: 'name'),
        TableColumnSpec(
          label: 'Страна',
          sortField: 'country',
          build: (b) => Text(b.country),
        ),
        TableColumnSpec(
          label: 'Моделей',
          sortField: 'models',
          numeric: true,
          build: (b) => Text('${b.models.length}'),
        ),
        TableColumnSpec(
          label: 'Модели',
          build: (b) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(b.models.join(', '), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class BrandDetailScreen extends StatelessWidget {
  const BrandDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return ReferenceDetailScreen<Brand, BrandListNotifier>(
      id: id,
      pageTitle: 'Марка',
      backLabel: 'К списку марок',
      notFoundText: 'Марка №$id не найдена',
      heading: (b) => b.name,
      labelOf: (b) => b.name,
      tiles: (b) => [
        InfoTile(label: 'Страна', value: Text(b.country)),
        InfoTile(label: 'Моделей', value: Text('${b.models.length}')),
        SizedBox(
          width: 560,
          child: InfoTile(label: 'Модели', value: Text(b.models.join(', '))),
        ),
      ],
      relatedTitle: 'Автомобили марки',
      relatedLocation: (b) => '/cars?brandId=${b.id}',
      relatedEmpty: 'Автомобилей этой марки нет — марку можно удалить.',
    );
  }
}

// ---- мастера ----

class MechanicListScreen extends StatelessWidget {
  const MechanicListScreen({super.key, required this.query});

  final EntityQuery query;

  @override
  Widget build(BuildContext context) {
    return ReferenceListScreen<Mechanic, MechanicListNotifier>(
      query: query,
      title: 'Мастера',
      addLabel: 'Добавить мастера',
      searchHint: 'ФИО или телефон',
      sortLabels: const {
        'name': 'ФИО',
        'grade': 'Разряд',
        'experience': 'Стаж',
      },
      filters: [
        ListFilter(
          key: 'grade',
          label: 'Разряд',
          allLabel: 'Любой',
          options: [for (var g = 1; g <= 6; g++) Option('$g', '$g разряд')],
        ),
      ],
      nouns: ('мастер', 'мастера', 'мастеров'),
      labelOf: (m) => m.shortName,
      cardTitle: (m) => m.fullName,
      cardSubtitle: (m) =>
          '${m.grade} разряд · стаж ${m.experience} '
          '${plural(m.experience, 'год', 'года', 'лет')}\n${m.phone}',
      hardDeleteNote: (m) =>
          'Мастер будет откреплён от всех автомобилей, сами автомобили останутся.',
      columns: [
        nameColumn<Mechanic>('ФИО', (m) => m.fullName, sortField: 'name'),
        TableColumnSpec(label: 'Телефон', build: (m) => Text(m.phone)),
        TableColumnSpec(
          label: 'Разряд',
          sortField: 'grade',
          numeric: true,
          build: (m) => Text('${m.grade}'),
        ),
        TableColumnSpec(
          label: 'Стаж',
          sortField: 'experience',
          numeric: true,
          build: (m) => Text(
            '${m.experience} ${plural(m.experience, 'год', 'года', 'лет')}',
          ),
        ),
        TableColumnSpec(
          label: 'В сервисе с',
          build: (m) => Text(formatDate(m.hiredAt)),
        ),
      ],
    );
  }
}

class MechanicDetailScreen extends StatelessWidget {
  const MechanicDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return ReferenceDetailScreen<Mechanic, MechanicListNotifier>(
      id: id,
      pageTitle: 'Мастер',
      backLabel: 'К списку мастеров',
      notFoundText: 'Мастер №$id не найден',
      heading: (m) => m.fullName,
      labelOf: (m) => m.shortName,
      tiles: (m) => [
        InfoTile(label: 'Телефон', value: SelectableText(m.phone)),
        InfoTile(label: 'Разряд', value: Text('${m.grade}')),
        InfoTile(
          label: 'Общий стаж',
          value: Text(
            '${m.experience} ${plural(m.experience, 'год', 'года', 'лет')}',
          ),
        ),
        InfoTile(label: 'В сервисе с', value: Text(formatDate(m.hiredAt))),
      ],
      relatedTitle: 'Закреплённые автомобили',
      relatedLocation: (m) => '/cars?mechanicId=${m.id}',
      relatedEmpty: 'За мастером пока не закреплено ни одного автомобиля.',
      hardDeleteNote: (m) =>
          'Мастер будет откреплён от всех автомобилей, сами автомобили останутся.',
    );
  }
}

// ---- услуги ----

class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key, required this.query});

  final EntityQuery query;

  @override
  Widget build(BuildContext context) {
    return ReferenceListScreen<ServiceItem, ServiceListNotifier>(
      query: query,
      title: 'Услуги',
      addLabel: 'Добавить услугу',
      searchHint: 'Название услуги',
      sortLabels: const {
        'name': 'Название',
        'price': 'Цена',
        'duration': 'Время',
      },
      filters: [
        ListFilter(
          key: 'category',
          label: 'Категория',
          allLabel: 'Все категории',
          options: [
            for (final c in ServiceCategory.values) Option(c.code, c.title),
          ],
        ),
      ],
      nouns: ('услуга', 'услуги', 'услуг'),
      labelOf: (s) => s.name,
      cardTitle: (s) => s.name,
      cardSubtitle: (s) =>
          '${s.category.title} · ${formatMoney(s.price)} · '
          '${formatDuration(s.duration)}',
      hardDeleteNote: (s) => 'Услуга будет убрана из заказов всех автомобилей.',
      columns: [
        nameColumn<ServiceItem>('Услуга', (s) => s.name, sortField: 'name'),
        TableColumnSpec(
          label: 'Категория',
          build: (s) => Text(s.category.title),
        ),
        TableColumnSpec(
          label: 'Цена',
          sortField: 'price',
          numeric: true,
          build: (s) => Text(formatMoney(s.price)),
        ),
        TableColumnSpec(
          label: 'Норма времени',
          sortField: 'duration',
          numeric: true,
          build: (s) => Text(formatDuration(s.duration)),
        ),
      ],
    );
  }
}

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return ReferenceDetailScreen<ServiceItem, ServiceListNotifier>(
      id: id,
      pageTitle: 'Услуга',
      backLabel: 'К списку услуг',
      notFoundText: 'Услуга №$id не найдена',
      heading: (s) => s.name,
      labelOf: (s) => s.name,
      tiles: (s) => [
        InfoTile(label: 'Категория', value: Text(s.category.title)),
        InfoTile(label: 'Цена', value: Text(formatMoney(s.price))),
        InfoTile(
          label: 'Норма времени',
          value: Text(formatDuration(s.duration)),
        ),
      ],
      relatedTitle: 'Автомобили с этой услугой в заказе',
      relatedLocation: (s) => '/cars?serviceId=${s.id}',
      relatedEmpty: 'Услуга пока не заказана ни для одного автомобиля.',
      hardDeleteNote: (s) => 'Услуга будет убрана из заказов всех автомобилей.',
    );
  }
}
