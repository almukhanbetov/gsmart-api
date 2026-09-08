import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/router/app_router.dart';
import 'package:gsmart/core/storage/session_storage.dart';
import 'package:gsmart/core/theme/app_theme.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app() => MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: AppRouter.router,
    );

LoginResponse _session() => LoginResponse.fromJson({
      'message': 'ok',
      'user': {
        'id': 1,
        'phone': '77000000001',
        'fullname': 'Иван Петров',
        'user_code': 1001,
        'bin': 'BIN',
      },
      'devices': [
        {
          'id': 1,
          'account': '1001001',
          'user_code': 1001,
          'device_name': 'Smart24 #1',
          'type': 1,
          'bin': '',
          'gruppa': '',
          'device_status': true,
          'server_status': true,
          'abon_time': null,
          'summa': 0,
          'signal_wifi': '-60',
          'status': true,
          'data_status': null,
          'data_inkas': null,
        }
      ],
      'money': [],
      'coin': [],
      'payments': [],
    });

/// Высокий вьюпорт, чтобы ленивый ListView строил все секции без прокрутки.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRouter.router.go('/'); // роутер — синглтон, сбрасываем маршрут между тестами
  });
  tearDown(() => SessionStore.instance.clear());

  testWidgets('без сессии открывается экран входа, без исключений',
      (tester) async {
    _tallViewport(tester);
    await SessionStore.instance.clear();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SMART24'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('с сессией открывается дашборд, без исключений', (tester) async {
    _tallViewport(tester);
    await SessionStore.instance.save(_session());
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Иван'), findsWidgets);
    expect(find.text('Выручка сегодня'), findsOneWidget);
    expect(find.text('Автоматы'), findsOneWidget);
    expect(find.text('Smart24 #1'), findsOneWidget);
  });

  testWidgets('переход на детали автомата', (tester) async {
    _tallViewport(tester);
    await SessionStore.instance.save(_session());
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Smart24 #1'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Характеристики'), findsOneWidget);
    expect(find.textContaining('Финансы'), findsOneWidget);
  });

  testWidgets('узкий экран 360px + тёмная тема — без overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await SessionStore.instance.save(_session());
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: AppRouter.router,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Smart24 #1'), findsOneWidget);
  });
}
