import '../../../core/api/api_client.dart';
import '../coin/models/coin_entry.dart';
import '../money/models/money_entry.dart';
import '../payments/models/payment_entry.dart';

/// Существующие endpoint (backend не меняется):
///   GET /api/money/:account
///   GET /api/coin/:account
///   GET /api/payments/:account
class TransactionsRepository {
  TransactionsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<MoneyResult> money(String account) async {
    final data = await _client.getJson('/api/money/$account');
    return MoneyResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<CoinResult> coin(String account) async {
    final data = await _client.getJson('/api/coin/$account');
    return CoinResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PaymentsResult> payments(String account) async {
    final data = await _client.getJson('/api/payments/$account');
    return PaymentsResult.fromJson((data as Map).cast<String, dynamic>());
  }
}
