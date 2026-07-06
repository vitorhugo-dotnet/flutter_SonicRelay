import 'package:dio/dio.dart';

import '../../devices/data/devices_repository.dart';
import '../domain/stream_session.dart';
import 'dto/join_session_request.dart';
import 'sessions_api.dart';

enum SessionsFailureKind {
  missingDevice,
  invalidCode,
  expiredCode,
  maxViewers,
  unauthorized,
  network,
  invalidResponse,
}

class SessionsFailure implements Exception {
  const SessionsFailure(this.kind, this.message);

  final SessionsFailureKind kind;
  final String message;
}

class SessionsRepository {
  SessionsRepository({
    required SessionsApi api,
    required DevicesRepository devicesRepository,
  }) : _api = api,
       _devicesRepository = devicesRepository;

  final SessionsApi _api;
  final DevicesRepository _devicesRepository;
  StreamSession? _currentSession;

  StreamSession? get currentSession => _currentSession;

  Future<StreamSession> join(String code) async {
    final deviceId = await _devicesRepository.readCurrentDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      throw const SessionsFailure(
        SessionsFailureKind.missingDevice,
        'This viewer is not registered yet. Retry device setup first.',
      );
    }

    try {
      final response = await _api.join(
        JoinSessionRequest(code: code.trim().toUpperCase(), deviceId: deviceId),
      );
      final session = response.toDomain();
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
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final text = data is Map
        ? '${data['code'] ?? ''} ${data['message'] ?? ''}'.toLowerCase()
        : data.toString().toLowerCase();

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
