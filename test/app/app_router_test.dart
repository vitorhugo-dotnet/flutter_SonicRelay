import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/router/app_router.dart';
import 'package:sonic_relay/features/auth/presentation/login_view_model.dart';

void main() {
  test('unauthenticated users cannot open protected routes', () {
    expect(authRedirect(const AuthState.unauthenticated(), '/join'), '/login');
  });

  test('authenticated users leave the login route', () {
    expect(authRedirect(const AuthState.authenticated(), '/login'), '/join');
  });
}
