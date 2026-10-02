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
/// Ответ без нужного списка считается ошибкой, а не пустой историей.
class TransactionsRepository {
  TransactionsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<MoneyResult> money(String account) async {
    return MoneyResult.fromJson(await _get('/api/money/$account', 'money'));
  }

  Future<CoinResult> coin(String account) async {
    return CoinResult.fromJson(await _get('/api/coin/$account', 'coin'));
  }

  Future<PaymentsResult> payments(String account) async {
    return PaymentsResult.fromJson(await _get('/api/payments/$account', 'payments'));
  }

  /// Запрос + проверка формата: в ответе обязан быть список [listKey].
  /// Неожиданный ответ — ошибка, а не «операций нет».
  Future<Map<String, dynamic>> _get(String path, String listKey) async {
    final token = SessionStore.instance.token;
    final dynamic data;
    try {
      data = await _client.getJson(path, token: token);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await SessionStore.instance.expire(token);
      rethrow;
    }
    if (data is! Map || data[listKey] is! List) {
      throw ApiException('Некорректный ответ сервера. Попробуйте позже.');
    }
    return data.cast<String, dynamic>();
  }
}
