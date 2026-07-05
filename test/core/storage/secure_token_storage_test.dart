import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/storage/secure_token_storage.dart';
import 'package:sonic_relay/features/auth/domain/auth_session.dart';

class FakeTokenStorage implements TokenStorage {
  AuthSession? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthSession?> read() async => value;

  @override
  Future<void> write(AuthSession session) async => value = session;
}

void main() {
  test('token storage contract round-trips and clears a session', () async {
    final storage = FakeTokenStorage();
    const session = AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 3600,
      tokenType: 'Bearer',
    );

    await storage.write(session);
    expect(await storage.read(), session);

    await storage.clear();
    expect(await storage.read(), isNull);
  });
}
