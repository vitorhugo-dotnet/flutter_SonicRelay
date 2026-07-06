import '../../domain/stream_session.dart';

class JoinSessionResponse {
  const JoinSessionResponse({
    required this.sessionId,
    required this.role,
    required this.signalingUrl,
  });

  factory JoinSessionResponse.fromJson(Map<String, Object?> json) {
    final sessionId = json['sessionId'];
    final role = json['role'];
    final signalingUrl = json['signalingUrl'];
    if (sessionId is! String ||
        sessionId.isEmpty ||
        role is! String ||
        role.isEmpty ||
        signalingUrl is! String ||
        signalingUrl.isEmpty) {
      throw const FormatException('Invalid join session response.');
    }
    return JoinSessionResponse(
      sessionId: sessionId,
      role: role,
      signalingUrl: signalingUrl,
    );
  }

  final String sessionId;
  final String role;
  final String signalingUrl;

  StreamSession toDomain() {
    final uri = Uri.tryParse(signalingUrl);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      throw const FormatException('Invalid signaling URL.');
    }
    return StreamSession(sessionId: sessionId, role: role, signalingUrl: uri);
  }
}
