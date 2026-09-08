import '../../../core/utils/json.dart';

/// Соответствует Go `type User` (backend/models.go) и `User` в mobile/src/lib/types.ts.
class User {
  const User({
    required this.id,
    required this.phone,
    required this.fullname,
    required this.userCode,
    required this.bin,
  });

  final int id;
  final String phone;
  final String fullname;
  final int userCode; // json: user_code
  final String bin;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: asInt(json['id']),
      phone: asString(json['phone']),
      fullname: asString(json['fullname']),
      userCode: asInt(json['user_code']),
      bin: asString(json['bin']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'fullname': fullname,
        'user_code': userCode,
        'bin': bin,
      };
}
