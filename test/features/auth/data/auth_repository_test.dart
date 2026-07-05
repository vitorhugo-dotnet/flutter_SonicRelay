import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/storage/secure_token_storage.dart';
import 'package:sonic_relay/features/auth/data/auth_api.dart';
import 'package:sonic_relay/features/auth/data/auth_repository.dart';
import 'package:sonic_relay/features/auth/data/dto/login_request.dart';
import 'package:sonic_relay/features/auth/data/dto/login_response.dart';
import 'package:sonic_relay/features/auth/data/dto/refresh_token_request.dart';
import 'package:sonic_relay/features/auth/domain/auth_session.dart';
import 'package:sonic_relay/features/auth/domain/auth_user.dart';

class FakeStorage implements TokenStorage {
  AuthSession? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async => value = session;
}

class FakeAuthApi implements AuthApi {
  LoginResponse response = const LoginResponse(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresIn: 3600,
    tokenType: 'Bearer',
  );
  bool logoutThrows = false;
  String? refreshedWith;

  @override
  Future<LoginResponse> login(LoginRequest request) async => response;
  @override
  Future<LoginResponse> refresh(RefreshTokenRequest request) async {
    refreshedWith = request.refreshToken;
    return response;
  }

  @override
  Future<void> logout() async {
    if (logoutThrows) throw Exception('offline');
  }

  @override
  Future<AuthUser> me() async => const AuthUser(id: '1', email: 'a@b.com');
}

void main() {
  late FakeStorage storage;
  late FakeAuthApi api;
  late AuthRepository repository;

  setUp(() {
    storage = FakeStorage();
    api = FakeAuthApi();
    repository = AuthRepository(api: api, tokenStorage: storage);
  });

  test('login persists the returned token pair', () async {
    final session = await repository.login(
      email: 'a@b.com',
      password: 'secret',
    );
    expect(storage.value?.accessToken, session.accessToken);
    expect(storage.value?.refreshToken, session.refreshToken);
    expect(session.user?.email, 'a@b.com');
  });

  test('refresh replaces persisted tokens', () async {
    storage.value = const AuthSession(
      accessToken: 'old',
      refreshToken: 'old-refresh',
      expiresIn: 1,
      tokenType: 'Bearer',
    );
    api.response = const LoginResponse(
      accessToken: 'new',
      refreshToken: 'new-refresh',
      expiresIn: 3600,
      tokenType: 'Bearer',
    );

    final session = await repository.refresh();
    expect(api.refreshedWith, 'old-refresh');
    expect(storage.value, session);
  });

  test('restore loads the current user for stored tokens', () async {
    storage.value = const AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 3600,
      tokenType: 'Bearer',
    );

    final session = await repository.restore();

    expect(session?.user?.email, 'a@b.com');
  });

  test('logout clears local tokens even when the API fails', () async {
    storage.value = const AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      expiresIn: 1,
      tokenType: 'Bearer',
    );
    api.logoutThrows = true;

    await repository.logout();
    expect(storage.value, isNull);
  });
}
