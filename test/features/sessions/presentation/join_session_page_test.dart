import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/features/sessions/data/dto/discoverable_session.dart';
import 'package:sonic_relay/features/sessions/data/sessions_repository.dart';
import 'package:sonic_relay/features/sessions/domain/stream_session.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_page.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_view_model.dart';
import 'package:sonic_relay/features/sessions/presentation/widgets/discovered_sessions_list.dart';

const _discoveredSession = DiscoverableSession(
  sessionId: '11111111-1111-1111-1111-111111111111',
  publisherDeviceName: 'VITOR-DESKTOP',
  status: 'waiting',
  viewerCount: 0,
  maxViewers: 3,
);

Widget _wrap({List<DiscoverableSession> discoverable = const []}) {
  return ProviderScope(
    overrides: [
      discoverableSessionsProvider.overrideWith(
        (ref) => Stream.value(discoverable),
      ),
    ],
    child: const MaterialApp(home: JoinSessionPage()),
  );
}

/// Records `joinById` calls instead of hitting a real backend, so the tap-to-join path can be
/// exercised without leaving a live Dio request pending after the test.
class _FakeSessionsRepository implements SessionsRepository {
  String? joinedSessionId;

  @override
  StreamSession? get currentSession => null;

  @override
  Future<List<DiscoverableSession>> discover() async => const [];

  @override
  Future<StreamSession> join(String code) => throw UnimplementedError();

  @override
  Future<StreamSession> joinById(String sessionId) async {
    joinedSessionId = sessionId;
    return StreamSession(
      sessionId: sessionId,
      signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
    );
  }
}

void main() {
  testWidgets('shows local validation before joining', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Join stream'));
    await tester.pump();

    expect(find.text('Enter a valid session code.'), findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(JoinSessionPage)),
      ).read(joinSessionViewModelProvider).validationMessage,
      'Enter a valid session code.',
    );
  });

  testWidgets('lists discovered sessions below the code field', (tester) async {
    await tester.pumpWidget(
      _wrap(discoverable: const [_discoveredSession]),
    );
    await tester.pumpAndSettle();

    expect(find.text('VITOR-DESKTOP'), findsOneWidget);
  });

  testWidgets('renders nothing extra when no session is discovered', (tester) async {
    await tester.pumpWidget(_wrap(discoverable: const []));
    await tester.pumpAndSettle();

    expect(find.byType(DiscoveredSessionsList), findsNothing);
  });

  testWidgets(
    'tapping a discovered session joins it by id and navigates to waiting',
    (tester) async {
      final repository = _FakeSessionsRepository();
      final router = GoRouter(
        initialLocation: '/join',
        routes: [
          GoRoute(path: '/join', builder: (_, _) => const JoinSessionPage()),
          GoRoute(
            path: '/session/waiting',
            builder: (_, _) => const Scaffold(body: Text('Waiting')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoverableSessionsProvider.overrideWith(
              (ref) => Stream.value(const [_discoveredSession]),
            ),
            sessionsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(repository.joinedSessionId, _discoveredSession.sessionId);
      expect(find.text('Waiting'), findsOneWidget);
    },
  );
}
