import '../../../core/format.dart';
import '../../auth/models/login_response.dart';

/// Агрегаты дашборда. Считаются на клиенте ТОЛЬКО из данных ответа login
/// (mobile использует те же поля). Никаких новых запросов и серверных полей.
class DashboardSummary {
  const DashboardSummary({
    required this.banknotesToday,
    required this.coinsToday,
    required this.cashlessToday,
    required this.deviceCount,
    required this.onlineCount,
    required this.avgSignal,
  });

  final int banknotesToday;
  final int coinsToday;
  final double cashlessToday;
  final int deviceCount;
  final int onlineCount;
  final int? avgSignal;

  num get revenueToday => banknotesToday + coinsToday + cashlessToday;
  int get offlineCount => deviceCount - onlineCount;

  factory DashboardSummary.of(LoginResponse s) {
    final banknotes = s.money
        .where((m) => isToday(m.createdAt))
        .fold<int>(0, (a, m) => a + m.payMoney);
    final coins = s.coin
        .where((c) => isToday(c.createdAt))
        .fold<int>(0, (a, c) => a + c.payCoin);
    final cashless = s.payments
        .where((p) => isToday(p.created))
        .fold<double>(0, (a, p) => a + p.sum);

    final online = s.devices.where((d) => d.status).length;

    final signals = s.devices
        .map((d) => signalQuality(d.signalWifi))
        .whereType<int>()
        .toList();
    final avg = signals.isEmpty
        ? null
        : (signals.reduce((a, b) => a + b) / signals.length).round();

    return DashboardSummary(
      banknotesToday: banknotes,
      coinsToday: coins,
      cashlessToday: cashless,
      deviceCount: s.devices.length,
      onlineCount: online,
      avgSignal: avg,
    );
  }
}
