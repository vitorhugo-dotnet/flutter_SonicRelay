import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final AuthUser? user;

  AuthSession copyWith({AuthUser? user}) => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresIn: expiresIn,
    tokenType: tokenType,
    user: user ?? this.user,
  );

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.expiresIn == expiresIn &&
      other.tokenType == tokenType &&
      other.user == user;

  @override
  int get hashCode =>
      Object.hash(accessToken, refreshToken, expiresIn, tokenType, user);
}
