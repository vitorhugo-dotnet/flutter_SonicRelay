import '../../domain/session_status.dart';
import '../../domain/stream_session.dart';

/// Parsed body of `POST /api/sessions/join`.
///
/// The backend returns a full StreamSession record — `{id, ownerUserId,
/// sourceDeviceId, status, maxViewers, codeExpiresAt, startedAt, endedAt,
/// createdAt, code}` — and no signaling URL. Only the fields the viewer needs
/// are read here; the signaling URL is built by the caller from the configured
/// WebSocket base URL (see [toDomain]).
class JoinSessionResponse {
  const JoinSessionResponse({
    required this.sessionId,
    required this.status,
    this.code,
  });

  factory JoinSessionResponse.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Invalid join session response.');
    }
    return JoinSessionResponse(
      sessionId: id,
      status: json['status'] as String? ?? 'waiting',
      code: json['code'] as String?,
    );
  }

  final String sessionId;
  final String status;
  final String? code;

  StreamSession toDomain(Uri signalingUrl) {
    if (signalingUrl.scheme != 'ws' && signalingUrl.scheme != 'wss') {
      throw const FormatException('Invalid signaling URL.');
    }
    return StreamSession(
      sessionId: sessionId,
      signalingUrl: signalingUrl,
      status: SessionStatus.fromWire(status),
    );
  }
}
