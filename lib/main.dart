import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'repositories/auth_api.dart';
import 'state/auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Адреса без решётки: /cars?page=2 вместо /#/cars?page=2.
  usePathUrlStrategy();

  // Для /auth/* — отдельный клиент без токена и без обновления токена.
  final auth = AuthNotifier(
    await SharedPreferences.getInstance(),
    AuthApi(buildDio()),
  );
  // Сессия восстанавливается до первого кадра: после перезагрузки
  // пользователь остаётся в системе и не видит мелькания экрана входа.
  await auth.restore();

  runApp(buildApp(auth: auth));
}
