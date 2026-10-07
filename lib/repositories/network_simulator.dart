import 'package:flutter/foundation.dart';

/// Учебные переключатели меню отладки.
///
/// Флаги добавляют к каждому запросу параметры, которые понимает учебный
/// сервер: `?__fail=500` — ответить ошибкой, `?__delay=1500` — ответить
/// с задержкой. Так экраны ошибки и загрузки проверяются на настоящем
/// сервере, без правки кода.
class NetworkSimulator extends ChangeNotifier {
  bool _failing = false;
  bool _slow = false;

  bool get failing => _failing;

  bool get slow => _slow;

  set slow(bool value) {
    if (_slow == value) return;
    _slow = value;
    notifyListeners();
  }

  set failing(bool value) {
    if (_failing == value) return;
    _failing = value;
    notifyListeners();
  }

  /// Параметры для интерсептора Dio.
  Map<String, Object> get queryParameters => {
    if (_failing) '__fail': 500,
    if (_slow) '__delay': 1500,
  };
}
