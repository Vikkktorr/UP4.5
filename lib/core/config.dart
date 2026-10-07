/// Адрес сервера задаётся при сборке, а не зашивается в код: на занятии
/// он один, дома другой, при публикации третий.
///
///   flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://192.168.1.10:8080/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

/// Выход по неактивности: три минуты без действий пользователя.
/// Предупреждение показывается за [inactivityWarning] до выхода.
const inactivityTimeout = Duration(
  seconds: int.fromEnvironment('INACTIVITY_SECONDS', defaultValue: 180),
);
const inactivityWarning = Duration(seconds: 30);

/// Общая длительность сессии: по её истечении пользователь выходит
/// независимо от активности, даже если токен обновлялся.
const sessionMaxDuration = Duration(
  minutes: int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 480),
);
