import '../../../../core/utils/json.dart';

/// Go `type Coin` / `CoinEntry` в mobile/src/lib/types.ts.
/// Внесение монетами.
class CoinEntry {
  const CoinEntry({
    required this.id,
    required this.account,
    required this.payCoin,
    required this.createdAt,
  });

  final int id;
  final int account;
  final int payCoin; // pay_coin
  final DateTime? createdAt; // created_at

  factory CoinEntry.fromJson(Map<String, dynamic> json) {
    return CoinEntry(
      id: asInt(json['id']),
      account: asInt(json['account']),
      payCoin: asInt(json['pay_coin']),
      createdAt: DateTime.tryParse(asString(json['created_at'])),
    );
  }
}

/// Ответ GET /api/coin/:account → `{ coin: [...], pay_coin_total: int }`
class CoinResult {
  const CoinResult({required this.items, required this.payCoinTotal});

  final List<CoinEntry> items;
  final int payCoinTotal;

  factory CoinResult.fromJson(Map<String, dynamic> json) {
    return CoinResult(
      items: asObjectList(json['coin']).map(CoinEntry.fromJson).toList(),
      payCoinTotal: asInt(json['pay_coin_total']),
    );
  }
}
