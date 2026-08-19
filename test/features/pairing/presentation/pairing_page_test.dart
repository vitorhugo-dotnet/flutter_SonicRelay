import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/features/pairing/data/pairing_repository.dart';
import 'package:sonic_relay/features/pairing/domain/device_pairing.dart';
import 'package:sonic_relay/features/pairing/domain/pairing_challenge_payload.dart';
import 'package:sonic_relay/features/pairing/presentation/pairing_page.dart';
import 'package:sonic_relay/features/pairing/presentation/pairing_view_model.dart';
import 'package:sonic_relay/features/sessions/data/dto/discoverable_session.dart';
import 'package:sonic_relay/features/sessions/data/dto/public_room_info.dart';
import 'package:sonic_relay/features/sessions/data/sessions_repository.dart';
import 'package:sonic_relay/features/sessions/domain/stream_session.dart';
import 'package:sonic_relay/features/sessions/presentation/widgets/public_room_card.dart';

const _publicRoomSessionId = 'public-room-session-id';
const _enabledPublicRoom = PublicRoomInfo(
  enabled: true,
  sessionId: _publicRoomSessionId,
  maxViewers: 20,
);

const challengeId = '00000000-0000-0000-0000-000000000001';
final existingPairing = DevicePairing(
  pairingId: 'pairing-existing',
  publisherDeviceId: 'publisher-existing',
  viewerDeviceId: 'viewer-1',
  status: 'active',
  createdAt: DateTime.utc(2026, 7, 29),
);

/// The Public Radio section now leads the pairing screen, pushing the manual pairing controls
/// and the Active pairings list further down than the default test viewport's cached/realized
/// extent covers. A generously tall viewport keeps every widget below it actually built, so
/// finders don't have to fight the same virtualization a real scroll gesture would resolve.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('keeps QR scan and manual pairing separate from session join', (
    tester,
  ) async {
    _useTallViewport(tester);
    final repository = _FakePairingRepository();
    await tester.pumpWidget(_app(repository));

    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.byKey(const Key('pairing-challenge-id')), findsOneWidget);
    expect(find.byKey(const Key('pairing-code')), findsOneWidget);
    expect(find.text('Join stream'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('pairing-challenge-id')),
      challengeId,
    );
    await tester.enterText(find.byKey(const Key('pairing-code')), 'abc12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Pair device'));
    await tester.pumpAndSettle();

    expect(repository.payload?.challengeId, challengeId);
    expect(repository.payload?.code, 'ABC12345');
    expect(find.text('Device paired.'), findsOneWidget);
  });

  testWidgets('shows generic invalid or expired pairing copy', (tester) async {
    _useTallViewport(tester);
    final repository = _FakePairingRepository()
      ..failure = const PairingFailure(
        PairingFailureKind.invalidOrExpired,
        'This pairing code is invalid or expired. Request a new code.',
      );
    await tester.pumpWidget(_app(repository));

    await tester.enterText(
      find.byKey(const Key('pairing-challenge-id')),
      challengeId,
    );
    await tester.enterText(find.byKey(const Key('pairing-code')), 'ABC12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Pair device'));
    await tester.pumpAndSettle();

    expect(
      find.text('This pairing code is invalid or expired. Request a new code.'),
      findsOneWidget,
    );
  });

  testWidgets('loads current device pairings once when the page opens', (
    tester,
  ) async {
    _useTallViewport(tester);
    final repository = _FakePairingRepository()..listed = [existingPairing];
    await tester.pumpWidget(_app(repository, deviceId: 'viewer-1'));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(repository.listedDeviceId, 'viewer-1');
    expect(find.text('Publisher publisher-existing'), findsOneWidget);

    tester.view.physicalSize = const Size(700, 1100);
    await tester.pump();

    expect(repository.listCalls, 1);
  });

  testWidgets('canceling revoke confirmation does not send DELETE', (
    tester,
  ) async {
    _useTallViewport(tester);
    final repository = _FakePairingRepository()..listed = [existingPairing];
    await tester.pumpWidget(_app(repository, deviceId: 'viewer-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke pairing?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.revokeCalls, 0);
    expect(find.text('Publisher publisher-existing'), findsOneWidget);
  });

  testWidgets('confirming revoke sends one DELETE and updates the list', (
    tester,
  ) async {
    _useTallViewport(tester);
    final repository = _FakePairingRepository()..listed = [existingPairing];
    await tester.pumpWidget(_app(repository, deviceId: 'viewer-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke pairing'));
    await tester.pumpAndSettle();

    expect(repository.revokeCalls, 1);
    expect(repository.revokedPairingId, 'pairing-existing');
    expect(find.text('Publisher publisher-existing'), findsNothing);
  });

  testWidgets('exposes a settings entry point that opens /settings', (
    tester,
  ) async {
    final repository = _FakePairingRepository();
    final router = GoRouter(
      initialLocation: '/pair',
      routes: [
        GoRoute(path: '/pair', builder: (_, _) => const PairingPage()),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('Settings page')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pairingRepositoryProvider.overrideWithValue(repository),
          currentPairingDeviceIdProvider.overrideWithValue(() async => null),
          publicRoomProvider.overrideWith(
            (ref) => Stream.value(const PublicRoomInfo.disabled()),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings page'), findsOneWidget);
  });

  testWidgets('exposes a how-to-use entry point that opens /how-to-use', (
    tester,
  ) async {
    final repository = _FakePairingRepository();
    final router = GoRouter(
      initialLocation: '/pair',
      routes: [
        GoRoute(path: '/pair', builder: (_, _) => const PairingPage()),
        GoRoute(
          path: '/how-to-use',
          builder: (_, _) => const Scaffold(body: Text('How to use page')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pairingRepositoryProvider.overrideWithValue(repository),
          currentPairingDeviceIdProvider.overrideWithValue(() async => null),
          publicRoomProvider.overrideWith(
            (ref) => Stream.value(const PublicRoomInfo.disabled()),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.byTooltip('How to use'));
    await tester.pumpAndSettle();

    expect(find.text('How to use page'), findsOneWidget);
  });

  testWidgets(
    'shows the Public Radio card on the pairing screen before any pairing exists',
    (tester) async {
      final repository = _FakePairingRepository();
      await tester.pumpWidget(_app(repository, publicRoom: _enabledPublicRoom));
      await tester.pumpAndSettle();

      expect(find.byType(PublicRoomCard), findsOneWidget);
      expect(find.text('Public Radio'), findsOneWidget);
    },
  );

  testWidgets('hides the Public Radio card when the room is disabled', (
    tester,
  ) async {
    final repository = _FakePairingRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.byType(PublicRoomCard), findsOneWidget);
    expect(find.text('Public Radio'), findsNothing);
  });

  testWidgets(
    'lets an unpaired user join Public Radio without a QR code, challenge ID, or pairing code',
    (tester) async {
      final pairingRepository = _FakePairingRepository();
      final sessionsRepository = _FakeSessionsRepository();
      final router = GoRouter(
        initialLocation: '/pair',
        routes: [
          GoRoute(path: '/pair', builder: (_, _) => const PairingPage()),
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
            pairingRepositoryProvider.overrideWithValue(pairingRepository),
            currentPairingDeviceIdProvider.overrideWithValue(() async => null),
            publicRoomProvider.overrideWith(
              (ref) => Stream.value(_enabledPublicRoom),
            ),
            sessionsRepositoryProvider.overrideWithValue(sessionsRepository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // No pairing details were ever entered — the manual fields on this same screen stay
      // untouched, confirming the join went through the code-free public-room path.
      expect(pairingRepository.payload, isNull);

      await tester.tap(find.byType(PublicRoomCard));
      await tester.pumpAndSettle();

      expect(sessionsRepository.joinedSessionId, _publicRoomSessionId);
      expect(find.text('Waiting'), findsOneWidget);
    },
  );

  testWidgets('shows a retryable error when joining Public Radio fails', (
    tester,
  ) async {
    final pairingRepository = _FakePairingRepository();
    final sessionsRepository = _FakeSessionsRepository()
      ..failure = const SessionsFailure(
        SessionsFailureKind.maxViewers,
        'This session has reached its viewer limit.',
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pairingRepositoryProvider.overrideWithValue(pairingRepository),
          currentPairingDeviceIdProvider.overrideWithValue(() async => null),
          publicRoomProvider.overrideWith(
            (ref) => Stream.value(_enabledPublicRoom),
          ),
          sessionsRepositoryProvider.overrideWithValue(sessionsRepository),
        ],
        child: const MaterialApp(home: PairingPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PublicRoomCard));
    await tester.pumpAndSettle();

    expect(
      find.text('This session has reached its viewer limit.'),
      findsOneWidget,
    );
  });
}

Widget _app(
  _FakePairingRepository repository, {
  String? deviceId,
  PublicRoomInfo publicRoom = const PublicRoomInfo.disabled(),
}) => ProviderScope(
  overrides: [
    pairingRepositoryProvider.overrideWithValue(repository),
    currentPairingDeviceIdProvider.overrideWithValue(() async => deviceId),
    // Avoids a real Dio call (and its dangling timer) when the pairing page mounts and
    // watches this provider eagerly for its Public Radio entry point.
    publicRoomProvider.overrideWith((ref) => Stream.value(publicRoom)),
  ],
  child: const MaterialApp(home: PairingPage()),
);

/// Records `joinById` calls instead of hitting a real backend, mirroring
/// join_session_page_test.dart's fake so the tap-to-join path can be exercised without leaving
/// a live Dio request pending after the test.
class _FakeSessionsRepository implements SessionsRepository {
  String? joinedSessionId;
  SessionsFailure? failure;

  @override
  StreamSession? get currentSession => null;

  @override
  Future<List<DiscoverableSession>> discover() async => const [];

  @override
  Future<StreamSession> join(String code) => throw UnimplementedError();

  @override
  Future<StreamSession> joinById(String sessionId) async {
    joinedSessionId = sessionId;
    if (failure case final value?) throw value;
    return StreamSession(
      sessionId: sessionId,
      signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
    );
  }

  @override
  Future<PublicRoomInfo> getPublicRoom() async =>
      const PublicRoomInfo.disabled();
}

class _FakePairingRepository implements PairingRepository {
  PairingChallengePayload? payload;
  PairingFailure? failure;
  List<DevicePairing> listed = const [];
  int listCalls = 0;
  String? listedDeviceId;
  int revokeCalls = 0;
  String? revokedPairingId;

  @override
  Future<DevicePairing> complete(PairingChallengePayload payload) async {
    this.payload = payload;
    if (failure case final value?) throw value;
    return DevicePairing(
      pairingId: 'pairing-1',
      publisherDeviceId: 'publisher-1',
      viewerDeviceId: 'viewer-1',
      status: 'active',
      createdAt: DateTime.utc(2026, 7, 29),
    );
  }

  @override
  Future<List<DevicePairing>> list(String deviceId) async {
    listCalls += 1;
    listedDeviceId = deviceId;
    return listed;
  }

  @override
  Future<void> revoke(String pairingId) async {
    revokeCalls += 1;
    revokedPairingId = pairingId;
  }
}
