import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/format.dart';
import 'package:gsmart/core/router/app_router.dart';
import 'package:gsmart/core/storage/session_storage.dart';
import 'package:gsmart/core/theme/app_theme.dart';
import 'package:gsmart/features/auth/data/auth_repository.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:gsmart/features/devices/presentation/widgets/finance_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Свежесть плиток «· сегодня» (из сессии /api/me) относительно общего итога
/// (из истории /api/money|coin|payments) на экране автомата.

String _at(int m, int d, [int h = 12, int mi = 0, int s = 0]) =>
    DateTime.utc(2026, m, d, h, mi, s).toIso8601String();
DateTime _almaty(int m, int d, [int h = 12, int mi = 0, int s = 0]) =>
    DateTime.utc(2026, m, d, h, mi, s).subtract(projectUtcOffset);

class _Server {
  List<Map<String, Object>> payments = [
    {'id': 1, 'txn_id': 'a', 'account': '1010', 'sum': 1200, 'result': 0, 'comment': '', 'created': _at(10, 3, 16)},
  ];
  int meCalls = 0;
  int historyCalls = 0;

  void addPayment(num sum, String created) => payments = [
        ...payments,
        {'id': payments.length + 1, 'txn_id': 'p${payments.length}', 'account': '1010', 'sum': sum, 'result': 0, 'comment': '', 'created': created},
      ];

  Map<String, Object> session() => {
        'user': {'id': 1, 'phone': 'x', 'fullname': 'x', 'user_code': 3, 'bin': ''},
        'devices': [
          {'id': 21, 'account': '1010', 'user_code': 3, 'device_name': '1', 'type': 1, 'bin': '',
           'gruppa': '', 'device_status': true, 'server_status': true, 'abon_time': null,
           'summa': 3000, 'signal_wifi': '-60', 'status': true, 'data_status': null, 'data_inkas': null}
        ],
        'money': [], 'coin': [], 'payments': payments,
      };

  Future<http.Response> handle(http.Request r) async {
    final seg = r.url.pathSegments;
    final Object body;
    if (r.url.path == '/api/me') {
      meCalls++;
      body = session();
    } else if (seg.length == 3 && seg[2] == '1010') {
      historyCalls++;
      body = {
        seg[1]: seg[1] == 'payments' ? payments : <Object>[],
        'pay_money_total': 0, 'pay_coin_total': 0, 'sum_total': 0,
      };
    } else {
      body = {'error': 'not found'};
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }
}

Future<void> _open(WidgetTester tester, _Server server) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  SessionStore.instance.repository = AuthRepository(); // HTTP из зоны теста
  await SessionStore.instance.save(LoginResponse.fromJson(server.session()), token: 'tok');
  AppRouter.router.go('/dashboard/1010');
  await tester.pumpWidget(MaterialApp.router(theme: AppTheme.dark(), routerConfig: AppRouter.router));
  await tester.pumpAndSettle();
}

/// Плитка «Безналичные» и общий итог за «Сегодня».
void _expectToday(num tile, num header) {
  // последняя «Безналичные» — плитка (первая — строка карточки «Финансы»)
  final paymentsTile = find
      .ancestor(of: find.text('Безналичные').last, matching: find.byType(Column))
      .first;
  expect(
      find.descendant(of: paymentsTile, matching: find.text('${formatTenge(tile)} · сегодня')),
      findsOneWidget,
      reason: 'плитка «Безналичные»');
  final total = find.descendant(
      of: find.byType(FinanceCard),
      matching: find.descendant(of: find.byType(FittedBox), matching: find.byType(Text)));
  expect((total.evaluate().single.widget as Text).data, formatTenge(header), reason: 'итог');
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  tearDown(() async {
    clock = DateTime.now;
    SessionStore.autoRefreshMinAge = const Duration(seconds: 15);
    await SessionStore.instance.clear();
  });

  testWidgets('в полночь плитки пересчитываются вместе с итогом', (tester) async {
    final server = _Server();
    clock = () => _almaty(10, 3, 23, 59, 30);
    await http.runWithClient(() async {
      await _open(tester, server);
      _expectToday(1200, 1200);

      clock = () => _almaty(10, 4, 0, 0, 30);
      await tester.pump(const Duration(seconds: 32)); // таймер полуночи
      _expectToday(0, 0); // вчерашние 1200 больше не «сегодня»
    }, () => MockClient(server.handle));
  });

  testWidgets('возврат из фона обновляет плитки и итог', (tester) async {
    final server = _Server();
    clock = () => _almaty(10, 3, 18);
    await http.runWithClient(() async {
      await _open(tester, server);
      server.addPayment(300, _at(10, 3, 17));
      SessionStore.autoRefreshMinAge = Duration.zero;
      for (final s in [
        AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused,
        AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      expect(server.meCalls, 1);
      _expectToday(1500, 1500);
    }, () => MockClient(server.handle));
  });

  testWidgets('«потянуть вниз» в истории обновляет и плитки экрана автомата',
      (tester) async {
    final server = _Server();
    clock = () => _almaty(10, 3, 18);
    await http.runWithClient(() async {
      await _open(tester, server);
      server.addPayment(300, _at(10, 3, 17));

      await tester.tap(find.text('Безналичные').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.text(formatTenge(1500)), findsWidgets); // история свежая
      expect(server.meCalls, 1); // и сессия обновлена

      AppRouter.router.go('/dashboard/1010');
      await tester.pumpAndSettle();
      _expectToday(1500, 1500);
    }, () => MockClient(server.handle));
  });

  testWidgets('«потянуть вниз» на экране автомата обновляет плитки и итог',
      (tester) async {
    final server = _Server();
    clock = () => _almaty(10, 3, 18);
    await http.runWithClient(() async {
      await _open(tester, server);
      final historyBefore = server.historyCalls;
      server.addPayment(300, _at(10, 3, 17));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(server.meCalls, 1);
      expect(server.historyCalls, historyBefore + 3); // итог перезагрузил историю
      _expectToday(1500, 1500);
    }, () => MockClient(server.handle));
  });
}
