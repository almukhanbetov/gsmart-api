import '../../../core/format.dart';
import '../../auth/models/login_response.dart';
import '../../devices/models/device.dart';
import '../../transactions/coin/models/coin_entry.dart';
import '../../transactions/money/models/money_entry.dart';
import '../../transactions/payments/models/payment_entry.dart';

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

  /// Разбивка купюры / монеты / безналичные за [from]..[to] включительно
  /// (календарные дни; даты из API — время Алматы, см. [isWithinRange]).
  /// Списки — история одного автомата. С [notAfter] (время Алматы, как
  /// [projectNow]) операции позже этого момента не учитываются.
  static PeriodBreakdown breakdownForPeriod({
    required List<MoneyEntry> money,
    required List<CoinEntry> coin,
    required List<PaymentEntry> payments,
    required DateTime from,
    required DateTime to,
    DateTime? notAfter,
  }) {
    bool inRange(DateTime? d) =>
        isWithinRange(d, from, to) &&
        (notAfter == null || !d!.isAfter(notAfter));
    return PeriodBreakdown(
      money: money
          .where((m) => inRange(m.createdAt))
          .fold<num>(0, (s, m) => s + m.payMoney),
      coin: coin
          .where((c) => inRange(c.createdAt))
          .fold<num>(0, (s, c) => s + c.payCoin),
      payments: payments
          .where((p) => inRange(p.created))
          .fold<num>(0, (s, p) => s + p.sum),
    );
  }

  /// Итог купюр + монет + безналичных — сумма [breakdownForPeriod].
  static num totalForPeriod({
    required List<MoneyEntry> money,
    required List<CoinEntry> coin,
    required List<PaymentEntry> payments,
    required DateTime from,
    required DateTime to,
    DateTime? notAfter,
  }) =>
      breakdownForPeriod(
        money: money,
        coin: coin,
        payments: payments,
        from: from,
        to: to,
        notAfter: notAfter,
      ).total;
}

/// Суммы по источникам за один период; [total] — ровно их сумма.
class PeriodBreakdown {
  const PeriodBreakdown({
    required this.money,
    required this.coin,
    required this.payments,
  });

  final num money;
  final num coin;
  final num payments;

  num get total => money + coin + payments;
}
