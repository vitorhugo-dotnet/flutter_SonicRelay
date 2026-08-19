import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/features/sessions/data/dto/discoverable_session.dart';
import 'package:sonic_relay/features/sessions/data/dto/public_room_info.dart';
import 'package:sonic_relay/features/sessions/data/sessions_repository.dart';
import 'package:sonic_relay/features/sessions/domain/stream_session.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_view_model.dart';

final joinedSession = StreamSession(
  sessionId: 'session-1',
  signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
);

const discoveredSession = DiscoverableSession(
  sessionId: 'session-42',
  publisherDeviceName: 'VITOR-DESKTOP',
  status: 'waiting',
  viewerCount: 0,
  maxViewers: 3,
);

class FakeSessionsRepository implements SessionsRepository {
  String? joinedCode;
  String? joinedSessionId;
  SessionsFailure? failure;

  @override
  StreamSession? get currentSession => null;

  @override
  Future<StreamSession> join(String code) async {
    joinedCode = code;
    if (failure case final value?) throw value;
    return joinedSession;
  }

  @override
  Future<List<DiscoverableSession>> discover() async => const [];

  @override
  Future<StreamSession> joinById(String sessionId) async {
    joinedSessionId = sessionId;
    if (failure case final value?) throw value;
    return joinedSession;
  }

  @override
  Future<PublicRoomInfo> getPublicRoom() async => const PublicRoomInfo.disabled();
}

class ReadyDeviceReadinessNotifier extends DeviceReadinessNotifier {
  @override
  DeviceReadinessState build() => const DeviceReadinessState.ready();
}

ProviderContainer createContainer(FakeSessionsRepository repository) {
  return ProviderContainer(
    overrides: [
      sessionsRepositoryProvider.overrideWithValue(repository),
      deviceReadinessProvider.overrideWith(ReadyDeviceReadinessNotifier.new),
    ],
  );
}

void main() {
  test(
    'normalizes code and blocks invalid input before repository call',
    () async {
      final repository = FakeSessionsRepository();
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final viewModel = container.read(joinSessionViewModelProvider.notifier);

      viewModel.updateCode(' ab ');
      expect(container.read(joinSessionViewModelProvider).code, 'AB');

      await viewModel.join();

      expect(repository.joinedCode, isNull);
      expect(
        container.read(joinSessionViewModelProvider).validationMessage,
        'Enter a valid session code.',
      );
    },
  );

  test('successful join exposes signaling session context', () async {
    final repository = FakeSessionsRepository();
    final container = createContainer(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(joinSessionViewModelProvider.notifier);

    viewModel.updateCode(' abc123 ');
    await viewModel.join();

    final state = container.read(joinSessionViewModelProvider);
    expect(repository.joinedCode, 'ABC123');
    expect(state.session, same(joinedSession));
    expect(state.status, JoinSessionStatus.joined);
  });

  test(
    'unauthorized join returns to device setup without account fallback',
    () async {
      final repository = FakeSessionsRepository()
        ..failure = const SessionsFailure(
          SessionsFailureKind.unauthorized,
          'Your device identity is no longer authorized.',
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final viewModel = container.read(joinSessionViewModelProvider.notifier);

      viewModel.updateCode('ABC123');
      await viewModel.join();

      expect(
        container.read(deviceReadinessProvider).status,
        DeviceReadinessStatus.deviceSetup,
      );
      expect(
        container.read(joinSessionViewModelProvider).errorMessage,
        'Your device identity is no longer authorized.',
      );
    },
  );

  test('manual retry join failure keeps device ready and offers retry', () async {
    final repository = FakeSessionsRepository()
      ..failure = const SessionsFailure(
        SessionsFailureKind.manualRetry,
        'Authorization refreshed. Retry joining the session.',
      );
    final container = createContainer(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(joinSessionViewModelProvider.notifier);

    viewModel.updateCode('ABC123');
    await viewModel.join();

    expect(
      container.read(deviceReadinessProvider).status,
      DeviceReadinessStatus.ready,
    );
    final state = container.read(joinSessionViewModelProvider);
    expect(state.canRetry, isTrue);
    expect(state.errorMessage, contains('Retry'));
  });

  test('normalises separators and casing into a six-character code', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final viewModel = container.read(joinSessionViewModelProvider.notifier);

    viewModel.updateCode(' sr-4f8k ');

    expect(container.read(joinSessionViewModelProvider).code, 'SR4F8K');
  });

  test('rejects a code that is not exactly six characters', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final viewModel = container.read(joinSessionViewModelProvider.notifier);

    viewModel.updateCode('ABC');
    await viewModel.join();

    expect(
      container.read(joinSessionViewModelProvider).validationMessage,
      isNotNull,
    );
  });

  test('joinDiscovered success exposes the joined session', () async {
    final repository = FakeSessionsRepository();
    final container = createContainer(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(joinSessionViewModelProvider.notifier);

    await viewModel.joinDiscovered(discoveredSession);

    final state = container.read(joinSessionViewModelProvider);
    expect(repository.joinedSessionId, discoveredSession.sessionId);
    expect(state.session, same(joinedSession));
    expect(state.status, JoinSessionStatus.joined);
  });

  test(
    'joinDiscovered surfaces a not-paired failure without offering retry',
    () async {
      final repository = FakeSessionsRepository()
        ..failure = const SessionsFailure(
          SessionsFailureKind.notPaired,
          'This device is no longer paired with that publisher. Pair again '
          'from the pairing screen, then retry.',
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final viewModel = container.read(joinSessionViewModelProvider.notifier);

      await viewModel.joinDiscovered(discoveredSession);

      final state = container.read(joinSessionViewModelProvider);
      expect(state.status, JoinSessionStatus.failed);
      expect(state.errorMessage, contains('no longer paired'));
      expect(state.canRetry, isFalse);
    },
  );

  test(
    'a retryable joinDiscovered failure retries the same session on retry()',
    () async {
      final repository = FakeSessionsRepository()
        ..failure = const SessionsFailure(
          SessionsFailureKind.network,
          'Unable to join the session. Check your connection and retry.',
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final viewModel = container.read(joinSessionViewModelProvider.notifier);

      await viewModel.joinDiscovered(discoveredSession);
      expect(container.read(joinSessionViewModelProvider).canRetry, isTrue);

      repository.failure = null;
      await viewModel.retry();

      final state = container.read(joinSessionViewModelProvider);
      expect(repository.joinedSessionId, discoveredSession.sessionId);
      expect(state.status, JoinSessionStatus.joined);
      expect(state.session, same(joinedSession));
    },
  );

  test('joinPublicRoom success exposes the joined session', () async {
    final repository = FakeSessionsRepository();
    final container = createContainer(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(joinSessionViewModelProvider.notifier);

    await viewModel.joinPublicRoom('public-room-session-id');

    final state = container.read(joinSessionViewModelProvider);
    expect(repository.joinedSessionId, 'public-room-session-id');
    expect(state.session, same(joinedSession));
    expect(state.status, JoinSessionStatus.joined);
  });

  test(
    'a retryable joinPublicRoom failure retries the same session on retry()',
    () async {
      final repository = FakeSessionsRepository()
        ..failure = const SessionsFailure(
          SessionsFailureKind.network,
          'Unable to join the session. Check your connection and retry.',
        );
      final container = createContainer(repository);
      addTearDown(container.dispose);
      final viewModel = container.read(joinSessionViewModelProvider.notifier);

      await viewModel.joinPublicRoom('public-room-session-id');
      expect(container.read(joinSessionViewModelProvider).canRetry, isTrue);

      repository.failure = null;
      await viewModel.retry();

      final state = container.read(joinSessionViewModelProvider);
      expect(repository.joinedSessionId, 'public-room-session-id');
      expect(state.status, JoinSessionStatus.joined);
      expect(state.session, same(joinedSession));
    },
  );
}
