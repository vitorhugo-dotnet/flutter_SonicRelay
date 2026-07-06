import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/features/auth/presentation/login_view_model.dart';
import 'package:sonic_relay/features/sessions/data/sessions_repository.dart';
import 'package:sonic_relay/features/sessions/domain/stream_session.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_view_model.dart';

final joinedSession = StreamSession(
  sessionId: 'session-1',
  signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
);

class FakeSessionsRepository implements SessionsRepository {
  String? joinedCode;
  SessionsFailure? failure;

  @override
  StreamSession? get currentSession => null;

  @override
  Future<StreamSession> join(String code) async {
    joinedCode = code;
    if (failure case final value?) throw value;
    return joinedSession;
  }
}

class AuthenticatedAuthViewModel extends AuthViewModel {
  @override
  AuthState build() => const AuthState.authenticated();
}

ProviderContainer createContainer(FakeSessionsRepository repository) {
  return ProviderContainer(
    overrides: [
      sessionsRepositoryProvider.overrideWithValue(repository),
      authViewModelProvider.overrideWith(AuthenticatedAuthViewModel.new),
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

  test('unauthorized join expires authentication', () async {
    final repository = FakeSessionsRepository()
      ..failure = const SessionsFailure(
        SessionsFailureKind.unauthorized,
        'Your session has expired. Please sign in again.',
      );
    final container = createContainer(repository);
    addTearDown(container.dispose);
    final viewModel = container.read(joinSessionViewModelProvider.notifier);

    viewModel.updateCode('ABC123');
    await viewModel.join();

    expect(container.read(authViewModelProvider).isAuthenticated, isFalse);
    expect(
      container.read(joinSessionViewModelProvider).errorMessage,
      'Your session has expired. Please sign in again.',
    );
  });
}
