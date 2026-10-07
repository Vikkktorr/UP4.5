import '../core/json.dart';

/// Уровень клубной карты.
enum CardLevel {
  standard('standard', 'Стандарт'),
  silver('silver', 'Серебряная'),
  gold('gold', 'Золотая');

  const CardLevel(this.code, this.title);

  final String code;
  final String title;

  static CardLevel? fromCode(Object? code) {
    for (final level in values) {
      if (level.code == code) return level;
    }
    return null;
  }
}

/// Клубная карта клиента — связь «один к одному»: у каждого клиента ровно
/// одна карта, и карта не существует без клиента. Отдельного экрана у неё
/// нет, поля редактируются вложенной группой в форме клиента.
class ClubCard {
  /// Номер вида «AS-000123».
  final String number;
  final CardLevel level;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int bonusPoints;

  const ClubCard({
    required this.number,
    this.level = CardLevel.standard,
    required this.issuedAt,
    required this.expiresAt,
    this.bonusPoints = 0,
  });

  bool isExpiredAt(DateTime date) => expiresAt.isBefore(date);

  Map<String, dynamic> toJson() => {
    'number': number,
    'level': level.code,
    'issuedAt': dateToJson(issuedAt),
    'expiresAt': dateToJson(expiresAt),
    'bonusPoints': bonusPoints,
  };

  factory ClubCard.fromJson(Map<String, dynamic> json) {
    final issued = readDate(json, 'issuedAt', DateTime(2000));
    return ClubCard(
      number: readString(json, 'number'),
      level: CardLevel.fromCode(json['level']) ?? CardLevel.standard,
      issuedAt: issued,
      // Без даты окончания карта считается действующей год с выдачи.
      expiresAt: readDate(
        json,
        'expiresAt',
        DateTime(issued.year + 1, issued.month, issued.day),
      ),
      bonusPoints: readInt(json, 'bonusPoints'),
    );
  }
}
