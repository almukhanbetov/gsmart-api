import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:gsmart/features/dashboard/models/dashboard_summary.dart';
import 'package:gsmart/shared/widgets/signal_bars.dart';

Map<String, dynamic> _device(String account, {bool status = true, String wifi = '-60'}) => {
      'id': int.parse(account),
      'account': account,
      'user_code': 1,
      'device_name': 'A',
      'type': 1,
      'bin': '',
      'gruppa': '',
      'device_status': true,
      'server_status': true,
      'abon_time': null,
      'summa': 0,
      'signal_wifi': wifi,
      'status': status,
      'data_status': null,
      'data_inkas': null,
    };

void main() {
  test('signalLevelFor границы', () {
    expect(signalLevelFor(null), SignalLevel.offline);
    expect(signalLevelFor(0), SignalLevel.offline);
    expect(signalLevelFor(20), SignalLevel.weak);
    expect(signalLevelFor(45), SignalLevel.medium);
    expect(signalLevelFor(70), SignalLevel.good);
    expect(signalLevelFor(95), SignalLevel.excellent);
  });

  test('DashboardSummary: счётчики online/offline и средний сигнал', () {
    final now = DateTime.now().toUtc().toIso8601String();
    final s = LoginResponse.fromJson({
      'message': 'ok',
      'user': {'id': 1, 'phone': 'x', 'fullname': 'x', 'user_code': 1, 'bin': ''},
      'devices': [
        _device('1', status: true, wifi: '-50'), // 100%
        _device('2', status: true, wifi: '-75'), // 50%
        _device('3', status: false, wifi: 'n/a'), // не учитывается в сигнале
      ],
      'money': [
        {'id': 1, 'account': 1, 'pay_money': 500, 'created_at': now},
      ],
      'coin': [
        {'id': 1, 'account': 2, 'pay_coin': 40, 'created_at': now},
      ],
      'payments': [
        {'id': 1, 'txn_id': 't', 'account': '1', 'sum': 10.0, 'result': 1,
            'comment': '', 'created': now},
      ],
    });

    final summary = DashboardSummary.of(s);
    expect(summary.deviceCount, 3);
    expect(summary.onlineCount, 2);
    expect(summary.offlineCount, 1);
    expect(summary.avgSignal, 75); // (100 + 50) / 2
    expect(summary.banknotesToday, 500);
    expect(summary.coinsToday, 40);
    expect(summary.cashlessToday, 10.0);
    expect(summary.revenueToday, 550);
  });
}
