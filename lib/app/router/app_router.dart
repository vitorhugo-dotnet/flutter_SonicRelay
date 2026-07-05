import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/listener/presentation/listener_page.dart';
import '../../features/sessions/presentation/join_session_page.dart';
import '../../features/settings/presentation/settings_page.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LoginPage()),
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
