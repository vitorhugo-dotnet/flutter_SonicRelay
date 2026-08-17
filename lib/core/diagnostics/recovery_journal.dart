import 'diagnostic_log.dart';

/// The fixed vocabulary of recovery steps, shared verbatim with the desktop
/// publisher's `RecoveryEvents`.
///
/// Recovery spans two client codebases and a backend, so a failed reconnect is
/// only diagnosable if both ends name the same step the same way — otherwise
/// correlating a viewer's log against a publisher's means translating between
/// two ad-hoc phrasings before the timeline even starts to make sense.
abstract final class RecoveryEvents {
  static const networkLost = 'network_lost';
  static const networkRestored = 'network_restored';
  static const recoveryStarted = 'recovery_started';
  static const recoveryCancelled = 'recovery_cancelled';
  static const staleAttemptIgnored = 'stale_attempt_ignored';
  static const signalingReconnectStarted = 'signaling_reconnect_started';
  static const signalingReconnectSucceeded = 'signaling_reconnect_succeeded';
  static const sessionRejoinStarted = 'session_rejoin_started';
  static const sessionRejoinSucceeded = 'session_rejoin_succeeded';
  static const iceRestartStarted = 'ice_restart_started';
  static const iceRestartSucceeded = 'ice_restart_succeeded';
  static const peerRebuildStarted = 'peer_rebuild_started';
  static const peerRebuildSucceeded = 'peer_rebuild_succeeded';
  static const mediaResumed = 'media_resumed';
  static const recoveryFailed = 'recovery_failed';
}

/// Records one line per recovery step, tagged with the connection generation and
/// attempt that produced it.
///
/// The generation is what makes an out-of-order log readable. A recovery attempt
/// that completes after a newer one has taken over still logs, and without a
/// generation stamp its lines are indistinguishable from the live attempt's —
/// which is exactly what makes "it said connected but no audio came back" so hard
/// to reconstruct after the fact.
///
/// Redaction is [DiagnosticLog]'s job and is deliberately not re-implemented here:
/// a recovery reason is usually a raw error string, which is where a token or an
/// SDP body leaks in.
class RecoveryJournal {
  const RecoveryJournal(this._log);

  final DiagnosticLog _log;

  static const _category = 'Recovery';

  Future<void> record(
    String event, {
    required int generation,
    int attempt = 0,
    Map<String, String>? properties,
  }) => _log.write(_category, event, {
    'generation': '$generation',
    'attempt': '$attempt',
    ...?properties,
  });
}
