import '../../../core/utils/json.dart';
import '../../devices/models/device.dart';
import '../../transactions/coin/models/coin_entry.dart';
import '../../transactions/money/models/money_entry.dart';
import '../../transactions/payments/models/payment_entry.dart';
import 'user.dart';

/// Ответ POST /api/login (backend/handlers.go → loginHandler).
///
/// Contract НЕ меняется: сервер возвращает `user` + все привязанные к
/// пользователю `devices`, `money`, `coin`, `payments` за один запрос.
class LoginResponse {
  const LoginResponse({
    required this.message,
    required this.user,
    required this.devices,
    required this.money,
    required this.coin,
    required this.payments,
  });

  final String message;
  final User user;
  final List<Device> devices;
  final List<MoneyEntry> money;
  final List<CoinEntry> coin;
  final List<PaymentEntry> payments;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: asString(json['message']),
      user: User.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      devices: asObjectList(json['devices']).map(Device.fromJson).toList(),
      money: asObjectList(json['money']).map(MoneyEntry.fromJson).toList(),
      coin: asObjectList(json['coin']).map(CoinEntry.fromJson).toList(),
      payments:
          asObjectList(json['payments']).map(PaymentEntry.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'user': user.toJson(),
        'devices': devices.map((d) => d.toJson()).toList(),
        // money/coin/payments сохраняем как есть — нужны для totals на дашборде
        'money': money
            .map((m) => {
                  'id': m.id,
                  'account': m.account,
                  'pay_money': m.payMoney,
                  'created_at': m.createdAt?.toIso8601String(),
                })
            .toList(),
        'coin': coin
            .map((c) => {
                  'id': c.id,
                  'account': c.account,
                  'pay_coin': c.payCoin,
                  'created_at': c.createdAt?.toIso8601String(),
                })
            .toList(),
        'payments': payments
            .map((p) => {
                  'id': p.id,
                  'txn_id': p.txnId,
                  'account': p.account,
                  'sum': p.sum,
                  'result': p.result,
                  'comment': p.comment,
                  'created': p.created?.toIso8601String(),
                })
            .toList(),
      };
}
