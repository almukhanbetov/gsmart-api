import '../../../core/api/api_client.dart';
import '../models/login_response.dart';

/// Результат входа: данные (контракт login не меняется) + токен сессии.
/// [token] может отсутствовать, если сервер старый или не смог создать сессию.
class LoginResult {
  const LoginResult({required this.response, required this.token});

  final LoginResponse response;
  final String? token;
}

/// POST /api/login, GET /api/me, POST /api/logout.
class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<LoginResult> login({
    required String phone,
    required String password,
  }) async {
    final data = await _client.postJson('/api/login', {
      'phone': phone,
      'password': password,
    });
    final json = (data as Map).cast<String, dynamic>();
    final token = json['token'];
    return LoginResult(
      response: LoginResponse.fromJson(json),
      token: token is String && token.isNotEmpty ? token : null,
    );
  }

  /// Актуальные данные владельца сессии — тот же формат, что у login.
  Future<LoginResponse> me(String token) async {
    final data = await _client.getJson('/api/me', token: token);
    return LoginResponse.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Отзыв сессии на сервере.
  Future<void> logout(String token) async {
    await _client.postJson('/api/logout', const {}, token: token);
  }
}
