import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../coin/models/coin_entry.dart';
import '../money/models/money_entry.dart';
import '../payments/models/payment_entry.dart';

/// Существующие endpoint (backend не меняется):
///   GET /api/money/:account
///   GET /api/coin/:account
///   GET /api/payments/:account
///
/// Запросы идут с токеном сессии — сервер отдаёт только свои автоматы.
/// 401 (сессии нет или она истекла) завершает сессию → экран входа.
class TransactionsRepository {
  TransactionsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<MoneyResult> money(String account) async {
    final data = await _get('/api/money/$account');
    return MoneyResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<CoinResult> coin(String account) async {
    final data = await _get('/api/coin/$account');
    return CoinResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PaymentsResult> payments(String account) async {
    final data = await _get('/api/payments/$account');
    return PaymentsResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<dynamic> _get(String path) async {
    final token = SessionStore.instance.token;
    try {
      return await _client.getJson(path, token: token);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await SessionStore.instance.expire(token);
      rethrow;
    }
  }
}
