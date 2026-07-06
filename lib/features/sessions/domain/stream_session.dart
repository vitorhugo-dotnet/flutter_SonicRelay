import 'session_status.dart';

class StreamSession {
  const StreamSession({
    required this.sessionId,
    required this.role,
    required this.signalingUrl,
    this.status = SessionStatus.waiting,
  });

  final String sessionId;
  final String role;
  final Uri signalingUrl;
  final SessionStatus status;
}
