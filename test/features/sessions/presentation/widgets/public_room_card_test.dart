import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/features/sessions/data/dto/discoverable_session.dart';
import 'package:sonic_relay/features/sessions/data/dto/public_room_info.dart';
import 'package:sonic_relay/features/sessions/data/sessions_repository.dart';
import 'package:sonic_relay/features/sessions/domain/stream_session.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_view_model.dart';
import 'package:sonic_relay/features/sessions/presentation/widgets/public_room_card.dart';

/// Never resolves, so the widget test can observe the `joining` state without racing a real
/// (or even fake-but-completing) join against `pumpAndSettle`/the test's pending-timer check.
class _NeverJoiningSessionsRepository implements SessionsRepository {
  @override
  StreamSession? get currentSession => null;

  @override
  Future<List<DiscoverableSession>> discover() async => const [];

  @override
  Future<StreamSession> join(String code) => Completer<StreamSession>().future;

  @override
  Future<StreamSession> joinById(String sessionId) =>
      Completer<StreamSession>().future;

  @override
  Future<PublicRoomInfo> getPublicRoom() async => const PublicRoomInfo.disabled();
}

Widget _wrap(PublicRoomInfo info, {SessionsRepository? repository}) {
  return ProviderScope(
    overrides: [
      publicRoomProvider.overrideWith((ref) => Stream.value(info)),
      if (repository != null)
        sessionsRepositoryProvider.overrideWithValue(repository),
    ],
    child: const MaterialApp(home: Scaffold(body: PublicRoomCard())),
  );
}

void main() {
  testWidgets('renders nothing while the public room is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const PublicRoomInfo.disabled()));
    await tester.pumpAndSettle();

    expect(find.byType(PublicRoomCard), findsOneWidget);
    expect(find.text('Public Radio'), findsNothing);
  });

  testWidgets('shows the max-viewers cap when enabled', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PublicRoomInfo(
          enabled: true,
          sessionId: 'public-room-session-id',
          maxViewers: 20,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Public Radio'), findsOneWidget);
    expect(find.textContaining('20'), findsOneWidget);
  });

  testWidgets('tapping the card joins the public room session', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PublicRoomInfo(
          enabled: true,
          sessionId: 'public-room-session-id',
          maxViewers: 20,
        ),
        repository: _NeverJoiningSessionsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PublicRoomCard));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PublicRoomCard)),
    );
    expect(
      container.read(joinSessionViewModelProvider).status,
      JoinSessionStatus.joining,
    );
  });
}
