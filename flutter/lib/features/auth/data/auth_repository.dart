import '../../../core/api/api_client.dart';
import '../models/login_response.dart';

/// POST /api/login — тот же контракт, что вызывает mobile/src/lib/api.ts.
class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<LoginResponse> login({
    required String phone,
    required String password,
  }) async {
    final data = await _client.postJson('/api/login', {
      'phone': phone,
      'password': password,
    });
    return LoginResponse.fromJson((data as Map).cast<String, dynamic>());
  }
}
