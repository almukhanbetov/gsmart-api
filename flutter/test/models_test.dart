import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/format.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:gsmart/features/dashboard/models/device_totals.dart';
import 'package:gsmart/features/devices/models/device.dart';
import 'package:gsmart/features/transactions/coin/models/coin_entry.dart';
import 'package:gsmart/features/transactions/money/models/money_entry.dart';
import 'package:gsmart/features/transactions/payments/models/payment_entry.dart';

void main() {
  group('models parse real backend JSON', () {
    test('Device.fromJson (nullable поля, int/float)', () {
      final d = Device.fromJson({
        'id': 5,
        'account': '1001001',
        'user_code': 1001,
        'device_name': 'Автомат №1',
        'type': 1,
        'bin': 'BIN-A',
        'gruppa': '',
        'device_status': true,
        'server_status': false,
        'abon_time': null,
        'summa': 0,
        'signal_wifi': '-67',
        'status': true,
        'data_status': null,
        'data_inkas': null,
      });
      expect(d.account, '1001001');
      expect(d.userCode, 1001);
      expect(d.abonTime, isNull);
      expect(d.summa, 0.0);
      expect(d.deviceStatus, true);
      expect(d.serverStatus, false);
    });

    test('MoneyResult / CoinResult totals', () {
      final money = MoneyResult.fromJson({
        'money': [
          {'id': 1, 'account': 1001001, 'pay_money': 500, 'created_at': '2026-09-08T10:00:00Z'},
          {'id': 2, 'account': 1001001, 'pay_money': 300, 'created_at': '2026-09-07T10:00:00Z'},
        ],
        'pay_money_total': 800,
      });
      expect(money.items, hasLength(2));
      expect(money.payMoneyTotal, 800);
      expect(money.items.first.createdAt, isNotNull);

      final coin = CoinResult.fromJson({'coin': [], 'pay_coin_total': 0});
      expect(coin.items, isEmpty);
      expect(coin.payCoinTotal, 0);
    });

    test('PaymentsResult (sum как float, created nullable, sum_total как 0)', () {
      final p = PaymentsResult.fromJson({
        'payments': [
          {
            'id': 10,
            'txn_id': 'txnA',
            'account': '1001001',
            'sum': 100.5,
            'result': 1,
            'comment': 'ok',
            'created': null,
          },
        ],
        'sum_total': 0,
      });
      expect(p.items.single.sum, 100.5);
      expect(p.items.single.created, isNull);
      expect(p.sumTotal, 0.0);
    });

    test('LoginResponse.fromJson + round-trip toJson', () {
      final json = {
        'message': 'Авторизация успешна',
        'user': {
          'id': 1,
          'phone': '77000000001',
          'fullname': 'User A',
          'user_code': 1001,
          'bin': 'BIN-A',
        },
        'devices': [
          {
            'id': 5,
            'account': '1001001',
            'user_code': 1001,
            'device_name': 'A',
            'type': 1,
            'bin': 'BIN-A',
            'gruppa': '',
            'device_status': true,
            'server_status': true,
            'abon_time': null,
            'summa': 0,
            'signal_wifi': '-50',
            'status': true,
            'data_status': null,
            'data_inkas': null,
          }
        ],
        'money': [
          {'id': 1, 'account': 1001001, 'pay_money': 500, 'created_at': '2026-09-08T10:00:00Z'},
        ],
        'coin': [],
        'payments': [],
      };

      final login = LoginResponse.fromJson(json);
      expect(login.user.userCode, 1001);
      expect(login.devices, hasLength(1));
      expect(login.money.single.payMoney, 500);

      // toJson должен снова разбираться
      final again = LoginResponse.fromJson(login.toJson());
      expect(again.user.phone, '77000000001');
      expect(again.money.single.account, 1001001);
    });
  });

  group('format helpers (перенос из mobile/src/lib/format.ts)', () {
    test('signalQuality', () {
      expect(signalQuality('-100'), 0);
      expect(signalQuality('-50'), 100);
      expect(signalQuality('-75'), 50);
      expect(signalQuality('abc'), isNull);
    });

    test('isWithinRange включительно по календарным дням', () {
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 9, 30);
      expect(isWithinRange(DateTime(2026, 9, 15, 23, 59), from, to), true);
      expect(isWithinRange(DateTime(2026, 9, 1), from, to), true);
      expect(isWithinRange(DateTime(2026, 8, 31), from, to), false);
      expect(isWithinRange(null, from, to), false);
    });

    test('formatTenge', () {
      expect(formatTenge(0), contains('₸'));
      expect(formatTenge(12345), contains('345'));
    });

    test('greeting по времени суток', () {
      expect(greeting(DateTime(2026, 1, 1, 3)), 'Доброй ночи');
      expect(greeting(DateTime(2026, 1, 1, 9)), 'Доброе утро');
      expect(greeting(DateTime(2026, 1, 1, 14)), 'Добрый день');
      expect(greeting(DateTime(2026, 1, 1, 21)), 'Добрый вечер');
    });

    test('initialsOf', () {
      expect(initialsOf('Иван Петров', 'S'), 'ИП');
      expect(initialsOf('Иван', 'S'), 'И');
      expect(initialsOf('', '77001'), '7');
    });
  });

  group('DeviceTotals — итоги "за сегодня" из ответа login', () {
    test('суммирует только сегодняшние операции нужного account', () {
      final today = DateTime.now();
      final iso = today.toUtc().toIso8601String();
      final login = LoginResponse.fromJson({
        'message': 'ok',
        'user': {
          'id': 1, 'phone': 'x', 'fullname': 'x', 'user_code': 1, 'bin': ''
        },
        'devices': [],
        'money': [
          {'id': 1, 'account': 1001001, 'pay_money': 500, 'created_at': iso},
          {'id': 2, 'account': 1001001, 'pay_money': 100,
              'created_at': '2020-01-01T00:00:00Z'}, // не сегодня
          {'id': 3, 'account': 9999999, 'pay_money': 999, 'created_at': iso}, // чужой
        ],
        'coin': [
          {'id': 1, 'account': 1001001, 'pay_coin': 20, 'created_at': iso},
        ],
        'payments': [
          {'id': 1, 'txn_id': 't', 'account': '1001001', 'sum': 30.0,
              'result': 1, 'comment': '', 'created': iso},
        ],
      });

      final device = Device.fromJson({
        'id': 5, 'account': '1001001', 'user_code': 1, 'device_name': 'A',
        'type': 1, 'bin': '', 'gruppa': '', 'device_status': true,
        'server_status': true, 'abon_time': null, 'summa': 0,
        'signal_wifi': '', 'status': true, 'data_status': null,
        'data_inkas': null,
      });

      final totals = DeviceTotals.forDevice(device, login);
      expect(totals.payMoneyToday, 500);
      expect(totals.payCoinToday, 20);
      expect(totals.paymentsToday, 30.0);
      expect(totals.total, 550);
    });
  });
}
