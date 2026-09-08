import '../../../../core/utils/json.dart';

/// Go `type Money` / `MoneyEntry` в mobile/src/lib/types.ts.
/// Внесение купюрами. `created_at` — RFC3339 (Go time.Time).
class MoneyEntry {
  const MoneyEntry({
    required this.id,
    required this.account,
    required this.payMoney,
    required this.createdAt,
  });

  final int id;
  final int account;
  final int payMoney; // pay_money
  final DateTime? createdAt; // created_at

  factory MoneyEntry.fromJson(Map<String, dynamic> json) {
    return MoneyEntry(
      id: asInt(json['id']),
      account: asInt(json['account']),
      payMoney: asInt(json['pay_money']),
      createdAt: DateTime.tryParse(asString(json['created_at'])),
    );
  }
}

/// Ответ GET /api/money/:account → `{ money: [...], pay_money_total: int }`
class MoneyResult {
  const MoneyResult({required this.items, required this.payMoneyTotal});

  final List<MoneyEntry> items;
  final int payMoneyTotal;

  factory MoneyResult.fromJson(Map<String, dynamic> json) {
    return MoneyResult(
      items: asObjectList(json['money']).map(MoneyEntry.fromJson).toList(),
      payMoneyTotal: asInt(json['pay_money_total']),
    );
  }
}
