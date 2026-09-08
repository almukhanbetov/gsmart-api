/// Ошибка обращения к API с уже человекочитаемым текстом.
/// В UI показывается [message], технические детали пользователю не видны.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
