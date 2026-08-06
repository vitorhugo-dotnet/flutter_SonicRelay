import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../data/dto/discoverable_session.dart';
import '../data/sessions_repository.dart';
import '../domain/stream_session.dart';

enum JoinSessionStatus { idle, joining, joined, failed }

class JoinSessionState {
  const JoinSessionState({
    this.code = '',
    this.status = JoinSessionStatus.idle,
    this.validationMessage,
    this.errorMessage,
    this.session,
    this.retryable = false,
  });

  final String code;
  final JoinSessionStatus status;
  final String? validationMessage;
  final String? errorMessage;
  final StreamSession? session;
  final bool retryable;

  bool get isJoining => status == JoinSessionStatus.joining;
  bool get canRetry => status == JoinSessionStatus.failed && retryable;
}

final joinSessionViewModelProvider =
    NotifierProvider<JoinSessionViewModel, JoinSessionState>(
      JoinSessionViewModel.new,
    );

class JoinSessionViewModel extends Notifier<JoinSessionState> {
  // Exactly what the backend accepts (SessionEndpoints.JoinAsync): six ASCII alphanumerics.
  // The old 4-12 pattern with hyphens let codes through that the server always rejected,
  // which surfaced to the user as a useless "invalid code".
  static final _validCode = RegExp(r'^[A-Z0-9]{6}$');
  late final SessionsRepository _repository;

  @override
  JoinSessionState build() {
    _repository = ref.watch(sessionsRepositoryProvider);
    return const JoinSessionState();
  }

  void updateCode(String value) {
    // Strip whitespace and hyphens anywhere in the string, not just at the ends, so a code
    // that was pasted or read aloud with separators still normalises to what the server wants.
    state = JoinSessionState(
      code: value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase(),
    );
  }

  Future<void> join() async {
    if (!_validCode.hasMatch(state.code)) {
      state = JoinSessionState(
        code: state.code,
        validationMessage: 'Enter a valid session code.',
      );
      return;
    }

    state = JoinSessionState(
      code: state.code,
      status: JoinSessionStatus.joining,
    );
    try {
      final session = await _repository.join(state.code);
      state = JoinSessionState(
        code: state.code,
        status: JoinSessionStatus.joined,
        session: session,
      );
    } on SessionsFailure catch (error) {
      var message = error.message;
      if (error.kind == SessionsFailureKind.unauthorized) {
        message = 'Your device identity is no longer authorized.';
        ref.read(deviceReadinessProvider.notifier).requireDeviceSetup(message);
      }
      state = JoinSessionState(
        code: state.code,
        status: JoinSessionStatus.failed,
        errorMessage: message,
        retryable:
            error.kind == SessionsFailureKind.network ||
            error.kind == SessionsFailureKind.manualRetry ||
            error.kind == SessionsFailureKind.missingDevice ||
            error.kind == SessionsFailureKind.invalidResponse,
      );
    } catch (_) {
      state = JoinSessionState(
        code: state.code,
        status: JoinSessionStatus.failed,
        errorMessage: 'Unable to join the session. Please retry.',
        retryable: true,
      );
    }
  }

  Future<void> retry() => join();

  Future<void> joinDiscovered(DiscoverableSession session) async {
    state = JoinSessionState(code: state.code, status: JoinSessionStatus.joining);
    try {
      final joined = await _repository.joinById(session.sessionId);
      state = JoinSessionState(
        code: state.code,
        status: JoinSessionStatus.joined,
        session: joined,
      );
    } on SessionsFailure catch (error) {
      state = JoinSessionState(
        code: state.code,
        status: JoinSessionStatus.failed,
        errorMessage: error.message,
        retryable: error.kind == SessionsFailureKind.network,
      );
    }
  }
}
