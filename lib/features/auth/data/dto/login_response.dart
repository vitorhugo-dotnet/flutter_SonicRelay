import '../../domain/auth_session.dart';

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresIn: (json['expiresIn'] as num).toInt(),
    tokenType: json['tokenType'] as String? ?? 'Bearer',
  );

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;

  AuthSession toSession() => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresIn: expiresIn,
    tokenType: tokenType,
  );
}
