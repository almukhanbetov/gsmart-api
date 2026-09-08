import '../../../../core/utils/json.dart';

/// Go `type Payment` / `PaymentEntry` в mobile/src/lib/types.ts.
/// Безналичный платёж. `created` может быть null.
class PaymentEntry {
  const PaymentEntry({
    required this.id,
    required this.txnId,
    required this.account,
    required this.sum,
    required this.result,
    required this.comment,
    required this.created,
  });

  final int id;
  final String txnId; // txn_id
  final String account;
  final double sum;
  final int result;
  final String comment;
  final DateTime? created; // created (nullable)

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    return PaymentEntry(
      id: asInt(json['id']),
      txnId: asString(json['txn_id']),
      account: asString(json['account']),
      sum: asDouble(json['sum']),
      result: asInt(json['result']),
      comment: asString(json['comment']),
      created: DateTime.tryParse(asString(json['created'])),
    );
  }
}

/// Ответ GET /api/payments/:account → `{ payments: [...], sum_total: number }`
class PaymentsResult {
  const PaymentsResult({required this.items, required this.sumTotal});

  final List<PaymentEntry> items;
  final double sumTotal;

  factory PaymentsResult.fromJson(Map<String, dynamic> json) {
    return PaymentsResult(
      items: asObjectList(json['payments']).map(PaymentEntry.fromJson).toList(),
      sumTotal: asDouble(json['sum_total']),
    );
  }
}
