import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../auth/presentation/login_view_model.dart';
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
  static final _validCode = RegExp(r'^[A-Z0-9-]{4,12}$');
  late final SessionsRepository _repository;

  @override
  JoinSessionState build() {
    _repository = ref.watch(sessionsRepositoryProvider);
    return const JoinSessionState();
  }

  void updateCode(String value) {
    state = JoinSessionState(code: value.trim().toUpperCase());
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
      if (error.kind == SessionsFailureKind.unauthorized) {
        ref.read(authViewModelProvider.notifier).expireSession();
      }
      state = JoinSessionState(
        code: state.code,
        status: JoinSessionStatus.failed,
        errorMessage: error.message,
        retryable:
            error.kind == SessionsFailureKind.network ||
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
}
