import 'package:dio/dio.dart';

import '../../../app/env/app_config.dart';
import '../../../core/http/manual_retry_required_exception.dart';
import '../domain/stream_session.dart';
import 'dto/discoverable_session.dart';
import 'dto/join_session_request.dart';
import 'sessions_api.dart';

enum SessionsFailureKind {
  missingDevice,
  invalidCode,
  expiredCode,
  maxViewers,
  notPaired,
  unauthorized,
  manualRetry,
  network,
  invalidResponse,
}

class SessionsFailure implements Exception {
  const SessionsFailure(this.kind, this.message);

  final SessionsFailureKind kind;
  final String message;
}

class SessionsRepository {
  SessionsRepository({required SessionsApi api, required AppConfig config})
    : _api = api,
      _config = config;

  final SessionsApi _api;
  final AppConfig _config;
  StreamSession? _currentSession;

  StreamSession? get currentSession => _currentSession;

  Future<StreamSession> join(String code) async {
    try {
      final response = await _api.join(
        JoinSessionRequest(code: code.trim().toUpperCase()),
      );
      final session = response.toDomain(_config.signalingUri);
      _currentSession = session;
      return session;
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    } on FormatException {
      throw const SessionsFailure(
        SessionsFailureKind.invalidResponse,
        'The server returned invalid session data. Please retry.',
      );
    }
  }

  /// Best-effort: discovery is an accelerator on top of manual code entry, so a failure
  /// returns an empty list rather than surfacing an error over a code field that still works.
  Future<List<DiscoverableSession>> discover() async {
    try {
      return await _api.discover();
    } catch (_) {
      return const [];
    }
  }

  Future<StreamSession> joinById(String sessionId) async {
    try {
      final response = await _api.joinById(sessionId);
      final session = response.toDomain(_config.signalingUri);
      _currentSession = session;
      return session;
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    } on FormatException {
      throw const SessionsFailure(
        SessionsFailureKind.invalidResponse,
        'The server returned invalid session data. Please retry.',
      );
    }
  }

  SessionsFailure _mapDioFailure(DioException error) {
    if (error.error is ManualRetryRequiredException) {
      return const SessionsFailure(
        SessionsFailureKind.manualRetry,
        'Authorization refreshed. Retry joining the session.',
      );
    }
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final text = data is Map
        ? '${data['code'] ?? ''} ${data['message'] ?? ''}'.toLowerCase()
        : data.toString().toLowerCase();

    if (status == 403 && data is Map && data['code'] == 'not_paired') {
      return const SessionsFailure(
        SessionsFailureKind.notPaired,
        'This device is no longer paired with that publisher. Pair again from the '
        'pairing screen, then retry.',
      );
    }
    if (status == 401 || status == 403) {
      return const SessionsFailure(
        SessionsFailureKind.unauthorized,
        'Your session has expired. Please sign in again.',
      );
    }
    if (status == 410 || text.contains('expired')) {
      return const SessionsFailure(
        SessionsFailureKind.expiredCode,
        'This session code has expired. Ask the publisher for a new code.',
      );
    }
    if (text.contains('max_viewers') || text.contains('max viewers')) {
      return const SessionsFailure(
        SessionsFailureKind.maxViewers,
        'This session has reached its viewer limit.',
      );
    }
    if (status == 400 || status == 404 || text.contains('invalid')) {
      return const SessionsFailure(
        SessionsFailureKind.invalidCode,
        'That session code is invalid. Check it and try again.',
      );
    }
    return const SessionsFailure(
      SessionsFailureKind.network,
      'Unable to join the session. Check your connection and retry.',
    );
  }
}
