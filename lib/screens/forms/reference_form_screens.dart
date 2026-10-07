import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/json.dart';
import '../../core/validators.dart';
import '../../models/brand.dart';
import '../../models/mechanic.dart';
import '../../models/service_item.dart';
import '../../repositories/brand_repository.dart';
import '../../repositories/mechanic_repository.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/entity_form/entity_form_screen.dart';
import '../../widgets/entity_form/form_spec.dart';

/// Формы трёх справочников. Каждая — только описание полей и функции
/// загрузки и сохранения; экран, проверка и отправка общие.

class BrandFormScreen extends StatelessWidget {
  const BrandFormScreen({super.key, this.id});

  final int? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<BrandRepository>();
    return EntityFormScreen(
      title: isEditing ? 'Изменение марки' : 'Новая марка',
      submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить марку',
      notFoundText: 'Марка №$id не найдена',
      onBack: () => context.go('/brands'),
      load: () async => isEditing
          ? (await repository.findById(id!))?.toJson()
          : {'id': 0, 'models': <String>[]},
      fields: brandFields,
      save: (json) async {
        final brand = Brand.fromJson(json);
        final saved = isEditing
            ? await repository.update(brand)
            : await repository.create(brand);
        return saved.id;
      },
      onSaved: (savedId) => context.go('/brands/$savedId'),
    );
  }
}

List<FormItem> brandFields(FormValues values) => [
  TextSpec(
    path: 'name',
    label: 'Название',
    maxLength: 30,
    validator: all([requiredText(), minLength(2), maxLength(30)]),
  ),
  TextSpec(
    path: 'country',
    label: 'Страна',
    maxLength: 30,
    capitalization: TextCapitalization.sentences,
    validator: all([requiredText(), minLength(2), maxLength(30), personName()]),
  ),
  TextSpec(
    path: 'models',
    label: 'Модели',
    kind: TextKind.list,
    hint: 'Granta, Vesta, Largus',
    helper: 'Через запятую. Из этого списка выбирается модель автомобиля',
    wide: true,
    validator: (value) {
      final models = splitList(value);
      if (models.isEmpty) return 'Укажите хотя бы одну модель';
      if (models.length > 40) return 'Не больше 40 моделей';
      for (final m in models) {
        if (m.length > 30) return '«$m» — длиннее 30 символов';
      }
      return null;
    },
  ),
];

class MechanicFormScreen extends StatelessWidget {
  const MechanicFormScreen({super.key, this.id});

  final int? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<MechanicRepository>();
    return EntityFormScreen(
      title: isEditing ? 'Изменение мастера' : 'Новый мастер',
      submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить мастера',
      notFoundText: 'Мастер №$id не найден',
      onBack: () => context.go('/mechanics'),
      load: () async => isEditing
          ? (await repository.findById(id!))?.toJson()
          : {
              'id': 0,
              'grade': 3,
              'capacity': 5,
              'hiredAt': dateToJson(DateTime.now()),
            },
      fields: mechanicFields,
      save: (json) async {
        final mechanic = Mechanic.fromJson(json);
        final saved = isEditing
            ? await repository.update(mechanic)
            : await repository.create(mechanic);
        return saved.id;
      },
      onSaved: (savedId) => context.go('/mechanics/$savedId'),
    );
  }
}

List<FormItem> mechanicFields(FormValues values) {
  final now = DateTime.now();
  return [
    TextSpec(
      path: 'lastName',
      label: 'Фамилия',
      maxLength: 40,
      capitalization: TextCapitalization.words,
      validator: all([
        requiredText(),
        minLength(2),
        maxLength(40),
        personName(),
      ]),
    ),
    TextSpec(
      path: 'firstName',
      label: 'Имя',
      maxLength: 30,
      capitalization: TextCapitalization.words,
      validator: all([requiredText(), maxLength(30), personName()]),
    ),
    TextSpec(
      path: 'middleName',
      label: 'Отчество',
      helper: 'Необязательно',
      maxLength: 30,
      capitalization: TextCapitalization.words,
      validator: optional([maxLength(30), personName()]),
    ),
    TextSpec(
      path: 'phone',
      label: 'Телефон',
      hint: '+7 (916) 123-45-67',
      maxLength: 18,
      keyboardType: TextInputType.phone,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+()\- ]'))],
      validator: all([requiredText(), phone()]),
    ),
    ChoiceSpec(
      path: 'grade',
      label: 'Разряд',
      options: [for (var g = 1; g <= 6; g++) Option(g, '$g разряд')],
      validator: requiredChoice('Выберите разряд'),
    ),
    DateSpec(
      path: 'hiredAt',
      label: 'Дата приёма',
      firstDate: DateTime(1980),
      lastDate: now,
      validator: notInFuture(),
    ),
    TextSpec(
      path: 'experience',
      label: 'Общий стаж',
      kind: TextKind.integer,
      suffix: 'лет',
      maxLength: 2,
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: intRange(0, 60, unit: 'лет'),
    ),
    TextSpec(
      path: 'capacity',
      label: 'Мест в графике',
      kind: TextKind.integer,
      helper: 'Сколько автомобилей мастер ведёт одновременно',
      maxLength: 2,
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: intRange(1, 10),
    ),
  ];
}

class ServiceFormScreen extends StatelessWidget {
  const ServiceFormScreen({super.key, this.id});

  final int? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ServiceRepository>();
    return EntityFormScreen(
      title: isEditing ? 'Изменение услуги' : 'Новая услуга',
      submitLabel: isEditing ? 'Сохранить изменения' : 'Добавить услугу',
      notFoundText: 'Услуга №$id не найдена',
      onBack: () => context.go('/services'),
      load: () async => isEditing
          ? (await repository.findById(id!))?.toJson()
          : {'id': 0, 'category': ServiceCategory.maintenance.code},
      fields: serviceFields,
      save: (json) async {
        final service = ServiceItem.fromJson(json);
        final saved = isEditing
            ? await repository.update(service)
            : await repository.create(service);
        return saved.id;
      },
      onSaved: (savedId) => context.go('/services/$savedId'),
    );
  }
}

List<FormItem> serviceFields(FormValues values) => [
  TextSpec(
    path: 'name',
    label: 'Название',
    maxLength: 60,
    wide: true,
    capitalization: TextCapitalization.sentences,
    validator: all([requiredText(), minLength(3), maxLength(60)]),
  ),
  ChoiceSpec(
    path: 'category',
    label: 'Категория',
    options: [for (final c in ServiceCategory.values) Option(c.code, c.title)],
    validator: requiredChoice('Выберите категорию'),
  ),
  TextSpec(
    path: 'price',
    label: 'Цена',
    kind: TextKind.integer,
    suffix: '₽',
    maxLength: 6,
    keyboardType: TextInputType.number,
    formatters: [FilteringTextInputFormatter.digitsOnly],
    validator: positive(max: 500000, unit: '₽'),
  ),
  TextSpec(
    path: 'duration',
    label: 'Норма времени',
    kind: TextKind.integer,
    suffix: 'мин',
    maxLength: 4,
    keyboardType: TextInputType.number,
    formatters: [FilteringTextInputFormatter.digitsOnly],
    validator: all([
      positive(max: 1440, unit: 'мин'),
      (v) => (int.tryParse(v) ?? 0) % 5 != 0 ? 'Кратно 5 минутам' : null,
    ]),
  ),
];
