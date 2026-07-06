import 'session_status.dart';

class StreamSession {
  const StreamSession({
    required this.sessionId,
    required this.signalingUrl,
    this.status = SessionStatus.waiting,
  });

  final String sessionId;
  final Uri signalingUrl;
  final SessionStatus status;
}
