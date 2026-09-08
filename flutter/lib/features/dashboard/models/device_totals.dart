import '../../../core/format.dart';
import '../../auth/models/login_response.dart';
import '../../devices/models/device.dart';

/// Итоги «за сегодня» по одному автомату.
/// Считаются на клиенте из данных, которые уже пришли в ответе login
/// (mobile показывает то же самое; здесь — без дополнительных запросов).
class DeviceTotals {
  const DeviceTotals({
    required this.payMoneyToday,
    required this.payCoinToday,
    required this.paymentsToday,
  });

  final int payMoneyToday;
  final int payCoinToday;
  final double paymentsToday;

  num get total => payMoneyToday + payCoinToday + paymentsToday;

  static DeviceTotals forDevice(Device device, LoginResponse session) {
    final accountInt = int.tryParse(device.account);

    final money = session.money
        .where((m) => m.account == accountInt && isToday(m.createdAt))
        .fold<int>(0, (s, m) => s + m.payMoney);

    final coin = session.coin
        .where((c) => c.account == accountInt && isToday(c.createdAt))
        .fold<int>(0, (s, c) => s + c.payCoin);

    final payments = session.payments
        .where((p) => p.account == device.account && isToday(p.created))
        .fold<double>(0, (s, p) => s + p.sum);

    return DeviceTotals(
      payMoneyToday: money,
      payCoinToday: coin,
      paymentsToday: payments,
    );
  }
}
