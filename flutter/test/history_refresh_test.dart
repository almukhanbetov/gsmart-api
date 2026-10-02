import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/api/api_client.dart';
import 'package:gsmart/core/api/api_exception.dart';
import 'package:gsmart/core/format.dart';
import 'package:gsmart/core/storage/session_storage.dart';
import 'package:gsmart/core/theme/app_theme.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:gsmart/features/transactions/data/transactions_repository.dart';
import 'package:gsmart/shared/widgets/date_range_bar.dart';
import 'package:gsmart/shared/widgets/transaction_history_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_refresh_test.dart' show sessionJson;

/// Время «как из API»: компоненты — Алматы, суффикс Z.
DateTime _almaty(int y, int m, int d, [int h = 0, int min = 0, int s = 0]) =>
    DateTime.utc(y, m, d, h, min, s);

/// Устанавливает «сейчас» по Алматы.
void _setAlmatyNow(DateTime almaty) =>
    clock = () => almaty.subtract(projectUtcOffset);

String _row(num amount) => '+ ${formatTenge(amount)}';

Finder _chip(String label) => find.descendant(
    of: find.byType(DateRangeBar), matching: find.text(label));

class _Server {
  _Server(this.rows);
  List<TxnRow> rows;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  Future<List<TxnRow>> load() async {
    calls++;
    final g = gate;
    if (g != null) await g.future;
    final e = error;
    if (e != null) throw e;
    return List.of(rows);
  }
}

Future<void> _open(WidgetTester tester, _Server server,
    {bool settle = true}) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: TransactionHistoryScreen(
      title: 'Купюры',
      subtitle: '№ 1001',
      accent: Colors.teal,
      rowIcon: Icons.receipt_long_rounded,
      loader: server.load,
    ),
  ));
  // пока запрос висит, скелет анимируется бесконечно
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

Future<void> _pull(WidgetTester tester) async {
  // порог RefreshIndicator — 25% высоты экрана (2400 → 600 px)
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionStore.instance.save(
        LoginResponse.fromJson(sessionJson()), token: 'tok');
    _setAlmatyNow(_almaty(2026, 10, 2, 12));
  });
  tearDown(() async {
    clock = DateTime.now;
    await SessionStore.instance.clear();
  });

  testWidgets('повторные обновления — данные стабильны', (tester) async {
    final server = _Server([
      TxnRow(id: 1, date: _almaty(2026, 10, 2, 9), amount: 100),
    ]);
    await _open(tester, server);

    for (var i = 0; i < 3; i++) {
      await _pull(tester);
      expect(find.text(_row(100)), findsOneWidget);
    }
    expect(server.calls, 4);

    // новая операция появляется после обновления
    server.rows = [
      ...server.rows,
      TxnRow(id: 2, date: _almaty(2026, 10, 2, 11), amount: 50),
    ];
    await _pull(tester);
    expect(find.text(_row(50)), findsOneWidget);
    expect(find.text(formatTenge(150)), findsOneWidget); // итог
    expect(tester.takeException(), isNull);
  });

  testWidgets('сетевая ошибка — последние данные и сообщение, «Повторить»',
      (tester) async {
    final server = _Server([
      TxnRow(id: 1, date: _almaty(2026, 10, 2, 9), amount: 100),
    ]);
    await _open(tester, server);

    server.error = ApiException('Нет подключения к серверу.');
    await _pull(tester);

    expect(find.text(_row(100)), findsOneWidget); // данные остались
    expect(find.text('Не удалось обновить данные'), findsOneWidget);
    expect(find.textContaining('Нет подключения к серверу.'), findsOneWidget);
    expect(find.text('Операций пока нет'), findsNothing);

    server.error = null;
    server.rows = [TxnRow(id: 2, date: _almaty(2026, 10, 2, 10), amount: 70)];
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось обновить данные'), findsNothing);
    expect(find.text(_row(70)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ошибка при первой загрузке — экран ошибки, не «операций нет»',
      (tester) async {
    final server = _Server(const [])
      ..error = ApiException('Некорректный ответ сервера. Попробуйте позже.');
    await _open(tester, server);

    expect(find.text('Не удалось загрузить данные'), findsOneWidget);
    expect(find.text('Операций пока нет'), findsNothing);

    server
      ..error = null
      ..rows = [TxnRow(id: 1, date: _almaty(2026, 10, 2, 9), amount: 100)];
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text(_row(100)), findsOneWidget);
  });

  testWidgets('успешный пустой ответ — «ещё не было поступлений»',
      (tester) async {
    await _open(tester, _Server(const []));
    expect(find.text('Операций пока нет'), findsOneWidget);
    expect(find.text('По этому автомату ещё не было поступлений'),
        findsOneWidget);
  });

  testWidgets('пусто только за период — «За выбранный период операций нет»',
      (tester) async {
    await _open(
        tester,
        _Server([
          TxnRow(id: 1, date: _almaty(2026, 9, 30, 9), amount: 100),
        ]));

    expect(find.text('За выбранный период операций нет'), findsOneWidget);
    expect(find.text('По этому автомату ещё не было поступлений'),
        findsNothing);

    await tester.tap(_chip('Неделя'));
    await tester.pumpAndSettle();
    expect(find.text(_row(100)), findsOneWidget);
  });

  testWidgets('одновременные обновления — один запрос', (tester) async {
    final server = _Server([
      TxnRow(id: 1, date: _almaty(2026, 10, 2, 9), amount: 100),
    ]);
    await _open(tester, server);
    expect(server.calls, 1);

    server.gate = Completer<void>();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // второй жест, пока первый запрос не завершён
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_row(100)), findsOneWidget); // данные видны во время загрузки
    server.gate!.complete();
    await tester.pumpAndSettle();

    expect(server.calls, 2);
    expect(find.text(_row(100)), findsOneWidget);
  });

  testWidgets('ответ, пришедший после смены пользователя, не применяется',
      (tester) async {
    final server = _Server([
      TxnRow(id: 1, date: _almaty(2026, 10, 2, 9), amount: 100),
    ])..gate = Completer<void>();
    await _open(tester, server, settle: false);

    await SessionStore.instance.save(
        LoginResponse.fromJson(sessionJson(name: 'Пётр')), token: 'other');
    server.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_row(100)), findsNothing);
  });

  group('границы суток по Asia/Almaty', () {
    testWidgets('00:00:00 — уже новый день, 23:59:59 — ещё прошлый',
        (tester) async {
      await _open(
          tester,
          _Server([
            TxnRow(id: 1, date: _almaty(2026, 10, 2, 0, 0, 0), amount: 100),
            TxnRow(id: 2, date: _almaty(2026, 10, 1, 23, 59, 59), amount: 200),
          ]));

      expect(find.text(_row(100)), findsOneWidget);
      expect(find.text(_row(200)), findsNothing);
      expect(find.text('02.10.26 — 02.10.26'), findsOneWidget);
    });

    testWidgets('после полуночи обновление показывает новый день',
        (tester) async {
      _setAlmatyNow(_almaty(2026, 10, 1, 23, 59, 30));
      final server = _Server([
        TxnRow(id: 1, date: _almaty(2026, 10, 1, 23, 50), amount: 100),
      ]);
      await _open(tester, server);
      expect(find.text(_row(100)), findsOneWidget);
      expect(find.text('01.10.26 — 01.10.26'), findsOneWidget);

      _setAlmatyNow(_almaty(2026, 10, 2, 0, 0, 30));
      server.rows = [
        ...server.rows,
        TxnRow(id: 2, date: _almaty(2026, 10, 2, 0, 0, 10), amount: 40),
      ];
      await _pull(tester);

      expect(find.text('02.10.26 — 02.10.26'), findsOneWidget);
      expect(find.text(_row(40)), findsOneWidget);
      expect(find.text(_row(100)), findsNothing); // вчерашняя
      expect(find.text(formatTenge(40)), findsOneWidget);

      // «Неделя» видит обе
      await tester.tap(_chip('Неделя'));
      await tester.pumpAndSettle();
      expect(find.text(_row(100)), findsOneWidget);
      expect(find.text(_row(40)), findsOneWidget);
    });
  });

  group('разбор ответа истории', () {
    Future<Object> fetch(String body, {int status = 200}) async {
      final repo = TransactionsRepository(
        client: ApiClient(
          baseUrl: 'http://t',
          client: MockClient((_) async => http.Response(body, status,
              headers: {'content-type': 'application/json; charset=utf-8'})),
        ),
      );
      try {
        return (await repo.money('1001')).items;
      } on ApiException catch (e) {
        return e;
      }
    }

    test('пустой список — успешный пустой результат', () async {
      expect(await fetch('{"money": [], "pay_money_total": 0}'), isEmpty);
    });

    test('неожиданный ответ — ошибка, а не пустой список', () async {
      for (final body in ['{}', '{"money": null}', '[]', '<html></html>', '']) {
        final r = await fetch(body);
        expect(r, isA<ApiException>(), reason: body);
        expect((r as ApiException).message,
            'Некорректный ответ сервера. Попробуйте позже.');
      }
    });

    test('ошибка сервера — ошибка', () async {
      final r = await fetch('{"error": "Ошибка получения money"}', status: 500);
      expect(r, isA<ApiException>());
      expect((r as ApiException).message, 'Ошибка получения money');
    });
  });
}
