import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/auth_session.dart';

abstract interface class TokenStorage {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _expiresInKey = 'auth.expiresIn';
  static const _tokenTypeKey = 'auth.tokenType';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final values = await _storage.readAll();
    final accessToken = values[_accessTokenKey];
    final refreshToken = values[_refreshTokenKey];
    if (accessToken == null || refreshToken == null) return null;
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: int.tryParse(values[_expiresInKey] ?? '') ?? 0,
      tokenType: values[_tokenTypeKey] ?? 'Bearer',
    );
  }

  @override
  Future<void> write(AuthSession session) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      _storage.write(key: _expiresInKey, value: '${session.expiresIn}'),
      _storage.write(key: _tokenTypeKey, value: session.tokenType),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresInKey),
      _storage.delete(key: _tokenTypeKey),
    ]);
  }
}
