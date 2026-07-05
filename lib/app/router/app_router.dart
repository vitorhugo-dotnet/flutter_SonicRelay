import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/login_view_model.dart';
import '../../features/listener/presentation/listener_page.dart';
import '../../features/sessions/presentation/join_session_page.dart';
import '../../features/settings/presentation/settings_page.dart';

String? authRedirect(AuthState auth, String location) {
  if (auth.status == AuthStatus.restoring) {
    return location == '/loading' ? null : '/loading';
  }
  if (!auth.isAuthenticated) {
    return location == '/login' ? null : '/login';
  }
  if (location == '/login' || location == '/loading') return '/join';
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) =>
        authRedirect(ref.read(authViewModelProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/loading',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinSessionPage(),
      ),
      GoRoute(
        path: '/listener',
        builder: (context, state) => const ListenerPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
  ref.listen(authViewModelProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
