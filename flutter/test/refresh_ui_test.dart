import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/format.dart';
import 'package:gsmart/core/router/app_router.dart';
import 'package:gsmart/core/storage/session_storage.dart';
import 'package:gsmart/core/theme/app_theme.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_refresh_test.dart' show jsonResponse, sessionJson, useServer;

Widget _app() => MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.router,
    );

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Сессия «как после перезапуска приложения»: копия с диска, обновлялась давно.
Future<void> _restoreStaleSession({
  bool deviceStatus = false,
  num summa = 3000,
}) async {
  SharedPreferences.setMockInitialValues({
    'session': jsonEncode(LoginResponse.fromJson(
            sessionJson(deviceStatus: deviceStatus, summa: summa))
        .toJson()),
    'session_token': 'tok',
    'session_updated_at': DateTime(2026, 1, 1).toIso8601String(),
  });
  await SessionStore.instance.load();
}

/// Свежий ответ /api/me: автомат включён, тариф 4 500, купюры сегодня 700.
Map<String, dynamic> _fresh() => {
      ...sessionJson(deviceStatus: true, summa: 4500),
      'money': [
        {
          'id': 1,
          'account': 1001001,
          'pay_money': 700,
          'created_at': projectNow().toIso8601String(),
        }
      ],
    };

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRouter.router.go('/');
  });
  tearDown(() async {
    SessionStore.autoRefreshMinAge = const Duration(seconds: 15);
    await SessionStore.instance.clear();
  });

  testWidgets('главная: обновление при открытии, данные видны во время загрузки',
      (tester) async {
    _tallViewport(tester);
    await _restoreStaleSession();
    final gate = Completer<http.Response>();
    final requests = useServer((_) => gate.future);

    await tester.pumpWidget(_app());
    await tester.pump(); // первый кадр → refresh
    await tester.pump();

    expect(requests, hasLength(1));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Мойка'), findsOneWidget); // старая копия на экране

    gate.complete(jsonResponse(_fresh()));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Не удалось обновить данные'), findsNothing);
    expect(SessionStore.instance.session!.devices.single.summa, 4500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('главная: сетевая ошибка → плашка и «Повторить»', (tester) async {
    _tallViewport(tester);
    await _restoreStaleSession();
    var online = false;
    final requests = useServer((_) async {
      if (!online) throw const SocketException('offline');
      return jsonResponse(_fresh());
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Не удалось обновить данные'), findsOneWidget);
    expect(find.textContaining('Нет подключения к серверу.'), findsOneWidget);
    expect(find.text('Мойка'), findsOneWidget); // последняя копия осталась

    online = true;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(find.text('Не удалось обновить данные'), findsNothing);
    expect(SessionStore.instance.session!.devices.single.summa, 4500);
  });

  testWidgets('главная: «потянуть вниз» запрашивает свежие данные',
      (tester) async {
    _tallViewport(tester);
    await SessionStore.instance.save(
        LoginResponse.fromJson(sessionJson(summa: 3000)),
        token: 'tok');
    final requests = useServer((_) async => jsonResponse(_fresh()));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(requests, isEmpty); // данные только что получены при входе

    // порог RefreshIndicator — 25% высоты экрана (2400 → 600 px)
    await tester.drag(find.text('Мойка'), const Offset(0, 900));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(SessionStore.instance.session!.devices.single.summa, 4500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('возврат из фона запускает обновление', (tester) async {
    _tallViewport(tester);
    await SessionStore.instance.save(
        LoginResponse.fromJson(sessionJson()),
        token: 'tok');
    final requests = useServer((_) async => jsonResponse(_fresh()));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(requests, isEmpty);

    SessionStore.autoRefreshMinAge = Duration.zero;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
  });

  testWidgets('экран автомата: обновление при открытии, характеристики свежие',
      (tester) async {
    _tallViewport(tester);
    await _restoreStaleSession(deviceStatus: false, summa: 3000);
    final requests = useServer((_) async => jsonResponse(_fresh()));
    AppRouter.router.go('/dashboard/1001001');

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // главная (в стеке под экраном) и экран автомата делят один запрос
    expect(requests, hasLength(1));
    expect(find.text('Тариф'), findsOneWidget);
    expect(find.text('включено'), findsOneWidget);
    expect(find.text('выключено'), findsNothing);
    expect(find.text(formatTenge(4500)), findsOneWidget);
    expect(find.text(formatTenge(700)), findsOneWidget); // купюры сегодня
    expect(tester.takeException(), isNull);
  });

  testWidgets('экран автомата: ошибка сети не стирает характеристики',
      (tester) async {
    _tallViewport(tester);
    await _restoreStaleSession(deviceStatus: false, summa: 3000);
    useServer((_) async => throw const SocketException('offline'));
    AppRouter.router.go('/dashboard/1001001');

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Не удалось обновить данные'), findsOneWidget);
    expect(find.text('выключено'), findsOneWidget);
    expect(find.text(formatTenge(3000)), findsOneWidget);
  });

  testWidgets('истёкшая сессия (401) → экран входа с причиной', (tester) async {
    _tallViewport(tester);
    await _restoreStaleSession();
    useServer((_) async =>
        jsonResponse({'error': 'Сессия истекла. Войдите снова'}, 401));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(SessionStore.instance.isLoggedIn, isFalse);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Сессия истекла. Войдите снова.'), findsOneWidget);
  });
}
