import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/format.dart';
import 'package:gsmart/core/router/app_router.dart';
import 'package:gsmart/core/storage/session_storage.dart';
import 'package:gsmart/core/theme/app_theme.dart';
import 'package:gsmart/features/auth/data/auth_repository.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:gsmart/features/dashboard/models/device_totals.dart';
import 'package:gsmart/features/devices/models/finance_period.dart';
import 'package:gsmart/features/devices/presentation/widgets/finance_card.dart';
import 'package:gsmart/features/transactions/coin/models/coin_entry.dart';
import 'package:gsmart/features/transactions/money/models/money_entry.dart';
import 'package:gsmart/features/transactions/payments/models/payment_entry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Время «как из API»: компоненты — Алматы, суффикс Z.
String _at(int m, int d, [int h = 12, int min = 0, int s = 0, int y = 2026]) =>
    DateTime.utc(y, m, d, h, min, s).toIso8601String();

/// Момент времени, когда в Алматы [y]-[m]-[d] [h]:[min]:[s].
DateTime _almatyInstant(int y, int m, int d, [int h = 12, int min = 0, int s = 0]) =>
    DateTime.utc(y, m, d, h, min, s).subtract(projectUtcOffset);

/// «Сейчас» — пятница 2 октября 2026, 12:00 по Алматы.
void _setNow([DateTime? instant]) {
  final t = instant ?? _almatyInstant(2026, 10, 2);
  clock = () => t;
}

// Данные автомата 1010 (даты — Алматы):
//   купюры: 500 (02.10 09:00), 300 (01.10 18:00)
//   монеты: 20 (02.10 00:00:00), 40 (27.09, воскресенье)
//   безнал: 30.5 (02.10 11:00), 100 (12.09), 10 (01.10 23:59:59),
//           5000 (02.10 15:00 — ещё не наступило), 7000 (03.10 — будущее)
// Итоги на 02.10 12:00:
//   Сегодня             02.10          = 500 + 20 + 30.5               = 550.5
//   Текущая неделя      28.09–02.10    = 550.5 + 300 + 10              = 860.5
//   Текущий месяц       01.10–02.10    = 860.5
//   Последние 7 дней    26.09–02.10    = 860.5 + 40                    = 900.5
//   Последние 30 дней   03.09–02.10    = 900.5 + 100                   = 1000.5
//   Период 10.09–30.09                 = 40 + 100                      = 140
final _money = [
  {'id': 1, 'account': 1010, 'pay_money': 500, 'created_at': _at(10, 2, 9)},
  {'id': 2, 'account': 1010, 'pay_money': 300, 'created_at': _at(10, 1, 18)},
];
final _coin = [
  {'id': 1, 'account': 1010, 'pay_coin': 20, 'created_at': _at(10, 2, 0, 0, 0)},
  {'id': 2, 'account': 1010, 'pay_coin': 40, 'created_at': _at(9, 27)},
];
final _payments = [
  {'id': 1, 'txn_id': 'a', 'account': '1010', 'sum': 30.5, 'result': 0, 'comment': '', 'created': _at(10, 2, 11)},
  {'id': 2, 'txn_id': 'b', 'account': '1010', 'sum': 100, 'result': 0, 'comment': '', 'created': _at(9, 12)},
  {'id': 3, 'txn_id': 'c', 'account': '1010', 'sum': 10, 'result': 0, 'comment': '', 'created': _at(10, 1, 23, 59, 59)},
  {'id': 4, 'txn_id': 'd', 'account': '1010', 'sum': 5000, 'result': 0, 'comment': '', 'created': _at(10, 2, 15)},
  {'id': 5, 'txn_id': 'e', 'account': '1010', 'sum': 7000, 'result': 0, 'comment': '', 'created': _at(10, 3, 9)},
];

num _totalFor(FinanceRange r) => DeviceTotals.totalForPeriod(
      money: _money.map(MoneyEntry.fromJson).toList(),
      coin: _coin.map(CoinEntry.fromJson).toList(),
      payments: _payments.map(PaymentEntry.fromJson).toList(),
      from: r.from,
      to: r.to,
      notAfter: projectNow(),
    );

class _Api {
  int historyCalls = 0;
  String? failKind; // этот раздел отвечает 500
  num moneyBoost = 0; // для «длинной суммы»
  List<Map<String, Object>> extraPayments = [];

  Future<http.Response> handle(http.Request req) async {
    final seg = req.url.pathSegments;
    if (req.url.path == '/api/me') {
      return _json(_sessionJson());
    }
    if (seg.length == 3 && seg[2] == '1010') {
      historyCalls++;
      if (req.headers['Authorization'] != 'Bearer tok') {
        return _json({'error': 'Требуется авторизация'}, 401);
      }
      final kind = seg[1];
      if (kind == failKind) return _json({'error': 'Ошибка получения $kind'}, 500);
      return switch (kind) {
        'money' => _json({
            'money': [
              ..._money,
              if (moneyBoost != 0)
                {'id': 9, 'account': 1010, 'pay_money': moneyBoost, 'created_at': _at(10, 2, 9)},
            ],
            'pay_money_total': 0,
          }),
        'coin' => _json({'coin': _coin, 'pay_coin_total': 0}),
        _ => _json({'payments': [..._payments, ...extraPayments], 'sum_total': 0}),
      };
    }
    return _json({'error': 'not found'}, 404);
  }

  static http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

Map<String, dynamic> _sessionJson() => {
      'user': {'id': 1, 'phone': 'x', 'fullname': 'x', 'user_code': 3, 'bin': ''},
      'devices': [
        {'id': 21, 'account': '1010', 'user_code': 3, 'device_name': 'Мойка 1010',
         'type': 1, 'bin': '', 'gruppa': '', 'device_status': true, 'server_status': true,
         'abon_time': '2026-08-10', 'summa': 3000, 'signal_wifi': '-60', 'status': true,
         'data_status': null, 'data_inkas': null}
      ],
      // данные плиток «за сегодня» — из сессии, отдельно от итога
      'money': [
        {'id': 1, 'account': 1010, 'pay_money': 777, 'created_at': _at(10, 2, 9)},
      ],
      'coin': [], 'payments': [],
    };

Finder get _header => find.byType(FinanceCard);
Finder _inHeader(Finder f) => find.descendant(of: _header, matching: f);

Future<void> _open(WidgetTester tester, _Api api,
    {double width = 430, ThemeMode theme = ThemeMode.dark}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  SessionStore.instance.repository = AuthRepository(); // HTTP из зоны теста
  await SessionStore.instance.save(LoginResponse.fromJson(_sessionJson()), token: 'tok');
  AppRouter.router.go('/dashboard/1010');
  await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: theme,
      routerConfig: AppRouter.router));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, FinancePeriod period) async {
  await tester.tap(_inHeader(find.byType(PopupMenuButton<FinancePeriod>)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(period.label).last);
  await tester.pumpAndSettle();
}

Future<void> _pickCustom(WidgetTester tester, String from, String to) async {
  await _pick(tester, FinancePeriod.custom);
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), from);
  await tester.enterText(fields.at(1), to);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// Крупный итог карточки (внутри FittedBox).
Finder get _cardTotal => _inHeader(
    find.descendant(of: find.byType(FittedBox), matching: find.byType(Text)));

void _expectHeader(String chip, String range, num total) {
  expect(_inHeader(find.text(chip)), findsOneWidget, reason: chip);
  expect(_inHeader(find.text(range)), findsOneWidget, reason: range);
  expect(_textOf(_cardTotal), formatTenge(total), reason: '$chip $total');
}

String? _textOf(Finder f) {
  final e = f.evaluate();
  return e.isEmpty ? null : (e.single.widget as Text).data;
}

/// Сумма строки разбивки карточки («—», пока итога нет).
String? _row(String label) {
  final row = find.ancestor(of: _inHeader(find.text(label)), matching: find.byType(Row)).first;
  final texts = find.descendant(of: row, matching: find.byType(Text)).evaluate()
      .map((e) => (e.widget as Text).data).where((t) => t != label).toList();
  return texts.single;
}

void _expectBreakdown(num money, num coin, num payments) {
  expect(_row('Купюры'), formatTenge(money), reason: 'Купюры');
  expect(_row('Монеты'), formatTenge(coin), reason: 'Монеты');
  expect(_row('Безналичные'), formatTenge(payments), reason: 'Безналичные');
  expect(_textOf(_cardTotal), formatTenge(money + coin + payments), reason: 'итог = сумма строк');
}

void _expectTiles() {
  // плитки не зависят от периода итога; подписи есть и в карточке, и в плитках
  expect(find.text('${formatTenge(777)} · сегодня'), findsOneWidget);
  for (final label in ['Купюры', 'Монеты', 'Безналичные']) {
    expect(find.text(label), findsNWidgets(2), reason: label);
    expect(_inHeader(find.text(label)), findsOneWidget, reason: label);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  setUp(_setNow);
  tearDown(() async {
    clock = DateTime.now;
    await SessionStore.instance.clear();
  });

  group('FinanceRange.of — календарные дни Asia/Almaty', () {
    FinanceRange r(FinancePeriod p, DateTime now) => FinanceRange.of(p, now: now);
    DateTime d(int y, int m, int day) => DateTime(y, m, day);

    test('пятница 02.10.2026', () {
      final now = _almatyInstant(2026, 10, 2);
      expect(r(FinancePeriod.today, now).label, '02.10.2026');
      expect(r(FinancePeriod.currentWeek, now).label, '28.09.2026 – 02.10.2026');
      expect(r(FinancePeriod.currentMonth, now).label, '01.10.2026 – 02.10.2026');
      expect(r(FinancePeriod.last7Days, now).label, '26.09.2026 – 02.10.2026');
      expect(r(FinancePeriod.last30Days, now).label, '03.09.2026 – 02.10.2026');
    });

    test('неделя: понедельник 00:00 и воскресенье 23:59:59', () {
      final mon = r(FinancePeriod.currentWeek, _almatyInstant(2026, 9, 28, 0, 0, 0));
      expect([mon.from, mon.to], [d(2026, 9, 28), d(2026, 9, 28)]);
      final sun = r(FinancePeriod.currentWeek, _almatyInstant(2026, 10, 4, 23, 59, 59));
      expect([sun.from, sun.to], [d(2026, 9, 28), d(2026, 10, 4)]);
      final nextMon = r(FinancePeriod.currentWeek, _almatyInstant(2026, 10, 5, 0, 0, 0));
      expect([nextMon.from, nextMon.to], [d(2026, 10, 5), d(2026, 10, 5)]);
    });

    test('переход месяца: 01.11', () {
      final now = _almatyInstant(2026, 11, 1, 0, 0, 0);
      expect(r(FinancePeriod.currentMonth, now).label, '01.11.2026');
      expect(r(FinancePeriod.last7Days, now).label, '26.10.2026 – 01.11.2026');
      expect(r(FinancePeriod.currentWeek, now).label, '26.10.2026 – 01.11.2026'); // воскресенье
    });

    test('переход года: пятница 01.01.2027', () {
      final now = _almatyInstant(2027, 1, 1, 10);
      expect(r(FinancePeriod.currentWeek, now).label, '28.12.2026 – 01.01.2027');
      expect(r(FinancePeriod.currentMonth, now).label, '01.01.2027');
      expect(r(FinancePeriod.last7Days, now).label, '26.12.2026 – 01.01.2027');
      expect(r(FinancePeriod.last30Days, now).label, '03.12.2026 – 01.01.2027');
    });

    test('високосный год: 01.03.2028', () {
      final now = _almatyInstant(2028, 3, 1);
      expect(r(FinancePeriod.last7Days, now).label, '24.02.2028 – 01.03.2028');
      expect(r(FinancePeriod.last30Days, now).label, '01.02.2028 – 01.03.2028'); // февраль 29 дней: 29 + 1 = 30
      expect(r(FinancePeriod.last30Days, _almatyInstant(2027, 3, 1)).label, '31.01.2027 – 01.03.2027');
    });

    test('полночь по Алматы, а не по UTC и не по поясу телефона', () {
      final before = DateTime.utc(2026, 10, 4, 18, 59, 59); // 23:59:59 Алматы
      final after = DateTime.utc(2026, 10, 4, 19); // 00:00:00 Алматы, 05.10
      expect(r(FinancePeriod.today, before).label, '04.10.2026');
      expect(r(FinancePeriod.today, after).label, '05.10.2026');
      expect(r(FinancePeriod.today, after.toLocal()).label, '05.10.2026');
      expect(r(FinancePeriod.currentWeek, after).label, '05.10.2026');
    });
  });

  group('DeviceTotals.totalForPeriod', () {
    test('все периоды; будущие операции не учитываются', () {
      expect(_totalFor(FinanceRange.of(FinancePeriod.today)), 550.5);
      expect(_totalFor(FinanceRange.of(FinancePeriod.currentWeek)), 860.5);
      expect(_totalFor(FinanceRange.of(FinancePeriod.currentMonth)), 860.5);
      expect(_totalFor(FinanceRange.of(FinancePeriod.last7Days)), 900.5);
      expect(_totalFor(FinanceRange.of(FinancePeriod.last30Days)), 1000.5);
      expect(_totalFor(FinanceRange(DateTime(2026, 9, 10), DateTime(2026, 9, 30))), 140);
    });

    test('начальная и конечная даты включаются полностью', () {
      final payments = [
        PaymentEntry.fromJson({'id': 1, 'sum': 1, 'created': _at(9, 28, 0, 0, 0)}),
        PaymentEntry.fromJson({'id': 2, 'sum': 2, 'created': _at(9, 30, 23, 59, 59)}),
        PaymentEntry.fromJson({'id': 3, 'sum': 4, 'created': _at(9, 27, 23, 59, 59)}),
        PaymentEntry.fromJson({'id': 4, 'sum': 8, 'created': _at(10, 1, 0, 0, 0)}),
      ];
      expect(
          DeviceTotals.totalForPeriod(
              money: const [], coin: const [], payments: payments,
              from: DateTime(2026, 9, 28), to: DateTime(2026, 9, 30),
              notAfter: projectNow()),
          3);
    });
  });

  group('DeviceTotals.breakdownForPeriod', () {
    PeriodBreakdown b(FinanceRange r) => DeviceTotals.breakdownForPeriod(
          money: _money.map(MoneyEntry.fromJson).toList(),
          coin: _coin.map(CoinEntry.fromJson).toList(),
          payments: _payments.map(PaymentEntry.fromJson).toList(),
          from: r.from,
          to: r.to,
          notAfter: projectNow(),
        );

    test('разбивка по каждому периоду; итог = сумма строк', () {
      final cases = {
        FinancePeriod.today: (500, 20, 30.5),
        FinancePeriod.currentWeek: (800, 20, 40.5),
        FinancePeriod.currentMonth: (800, 20, 40.5),
        FinancePeriod.last7Days: (800, 60, 40.5),
        FinancePeriod.last30Days: (800, 60, 140.5),
      };
      cases.forEach((p, e) {
        final r = b(FinanceRange.of(p));
        expect([r.money, r.coin, r.payments], [e.$1, e.$2, e.$3], reason: p.label);
        expect(r.total, e.$1 + e.$2 + e.$3, reason: p.label);
        expect(r.total, _totalFor(FinanceRange.of(p)), reason: '${p.label}: та же сумма, что totalForPeriod');
      });
      final custom = b(FinanceRange(DateTime(2026, 9, 10), DateTime(2026, 9, 30)));
      expect([custom.money, custom.coin, custom.payments, custom.total], [0, 40, 100, 140]);
    });
  });

  testWidgets('строки карточки — за тот же период, что итог', (tester) async {
    final api = _Api();
    await http.runWithClient(() async {
      await _open(tester, api);
      _expectBreakdown(500, 20, 30.5);
      await _pick(tester, FinancePeriod.currentWeek);
      _expectBreakdown(800, 20, 40.5);
      await _pick(tester, FinancePeriod.currentMonth);
      _expectBreakdown(800, 20, 40.5);
      await _pick(tester, FinancePeriod.last7Days);
      _expectBreakdown(800, 60, 40.5);
      await _pick(tester, FinancePeriod.last30Days);
      _expectBreakdown(800, 60, 140.5);
      await _pickCustom(tester, '09/10/2026', '09/30/2026');
      _expectBreakdown(0, 40, 100);
      _expectTiles(); // плитки за сегодня не изменились
      // строки — без переходов и стрелок
      expect(_inHeader(find.byIcon(Icons.chevron_right_rounded)), findsNothing);
      for (final label in ['Купюры', 'Монеты', 'Безналичные']) {
        final row = find.ancestor(of: _inHeader(find.text(label)), matching: find.byType(Row)).first;
        expect(find.descendant(of: row, matching: find.byType(InkWell)), findsNothing, reason: label);
        expect(find.descendant(of: row, matching: find.byType(GestureDetector)), findsNothing, reason: label);
      }
      expect(api.historyCalls, 3);
    }, () => MockClient(api.handle));
  });

  testWidgets('по умолчанию «Сегодня»; каждый пункт — свой диапазон и итог',
      (tester) async {
    final api = _Api();
    await http.runWithClient(() async {
      await _open(tester, api);

      expect(api.historyCalls, 3); // money + coin + payments, с токеном
      _expectHeader('Сегодня', '02.10.2026', 550.5);
      _expectTiles();

      await _pick(tester, FinancePeriod.currentWeek);
      _expectHeader('Текущая неделя', '28.09.2026 – 02.10.2026', 860.5);
      await _pick(tester, FinancePeriod.currentMonth);
      _expectHeader('Текущий месяц', '01.10.2026 – 02.10.2026', 860.5);
      await _pick(tester, FinancePeriod.last7Days);
      _expectHeader('Последние 7 дней', '26.09.2026 – 02.10.2026', 900.5);
      await _pick(tester, FinancePeriod.last30Days);
      _expectHeader('Последние 30 дней', '03.09.2026 – 02.10.2026', 1000.5);
      _expectTiles();

      expect(api.historyCalls, 3); // смена периода не делает новых запросов
      expect(tester.takeException(), isNull);
    }, () => MockClient(api.handle));
  });

  testWidgets('«Период…»: начальная и конечная даты', (tester) async {
    final api = _Api();
    await http.runWithClient(() async {
      await _open(tester, api);
      await _pickCustom(tester, '09/10/2026', '09/30/2026');
      _expectHeader('Период', '10.09.2026 – 30.09.2026', 140);
      _expectTiles();
      expect(tester.takeException(), isNull);
    }, () => MockClient(api.handle));
  });

  testWidgets('в полночь границы и итог пересчитываются', (tester) async {
    _setNow(_almatyInstant(2026, 10, 4, 23, 59, 30)); // воскресенье
    final api = _Api()
      ..extraPayments = [
        {'id': 20, 'txn_id': 'x', 'account': '1010', 'sum': 70, 'result': 0, 'comment': '', 'created': _at(10, 4, 23, 59)},
        {'id': 21, 'txn_id': 'y', 'account': '1010', 'sum': 3, 'result': 0, 'comment': '', 'created': _at(10, 5, 0, 0, 10)},
      ];
    await http.runWithClient(() async {
      await _open(tester, api);
      await _pick(tester, FinancePeriod.currentWeek);
      // 28.09–04.10: 860.5 + 7000 (03.10) + 70 (04.10); операция 05.10 — ещё в будущем
      _expectHeader('Текущая неделя', '28.09.2026 – 04.10.2026', 860.5 + 5000 + 7000 + 70);

      _setNow(_almatyInstant(2026, 10, 5, 0, 0, 30)); // понедельник
      await tester.pump(const Duration(seconds: 32)); // таймер полуночи
      _expectHeader('Текущая неделя', '05.10.2026', 3);
      expect(api.historyCalls, 3); // без новых запросов
    }, () => MockClient(api.handle));
  });

  testWidgets('после обновления данных история перезагружается', (tester) async {
    final api = _Api();
    await http.runWithClient(() async {
      await _open(tester, api);
      expect(api.historyCalls, 3);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await SessionStore.instance.refresh(); // GET /api/me → updatedAt
      await tester.pumpAndSettle();
      expect(api.historyCalls, 6);
      _expectHeader('Сегодня', '02.10.2026', 550.5);
    }, () => MockClient(api.handle));
  });

  testWidgets('ошибка одного раздела — нет итога и нуля, есть «Повторить»',
      (tester) async {
    final api = _Api()..failKind = 'payments';
    await http.runWithClient(() async {
      await _open(tester, api);

      expect(_inHeader(find.text('Повторить')), findsOneWidget);
      expect(_inHeader(find.textContaining('₸')), findsNothing); // ни 0, ни частичной суммы
      expect([_row('Купюры'), _row('Монеты'), _row('Безналичные')], ['—', '—', '—']);
      expect(_inHeader(find.text('02.10.2026')), findsOneWidget); // период виден
      _expectTiles();

      api.failKind = null;
      await tester.tap(_inHeader(find.text('Повторить')));
      await tester.pumpAndSettle();
      _expectHeader('Сегодня', '02.10.2026', 550.5);
      _expectBreakdown(500, 20, 30.5);
    }, () => MockClient(api.handle));
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('узкий экран, длинные пункты и сумма, ${theme.name} — без overflow',
        (tester) async {
      final api = _Api()..moneyBoost = 987654321012;
      await http.runWithClient(() async {
        await _open(tester, api, width: 320, theme: theme);
        for (final p in [FinancePeriod.last30Days, FinancePeriod.currentMonth, FinancePeriod.last7Days]) {
          await _pick(tester, p);
          expect(tester.takeException(), isNull, reason: p.label);
        }
        await _pickCustom(tester, '09/10/2026', '10/02/2026');
        expect(_inHeader(find.text('10.09.2026 – 02.10.2026')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(_header).right, lessThanOrEqualTo(320 - 16 + 0.5));
      }, () => MockClient(api.handle));
    });
  }
}
