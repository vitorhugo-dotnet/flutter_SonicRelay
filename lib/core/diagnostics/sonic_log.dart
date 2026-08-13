import 'package:flutter/foundation.dart';

/// Receives every [sonicLog] line, in addition to `debugPrint`.
typedef SonicLogSink = void Function(String tag, String message);

SonicLogSink? _sink;

/// Routes subsequent [sonicLog] lines to [sink], or back to `debugPrint` only
/// when null.
///
/// `main()` points this at the app's `DiagnosticLog` so the tagged signaling and
/// WebRTC flow reaches the log the user can export. Without it those lines exist
/// solely in `adb logcat`, which is unavailable on a phone that has been
/// streaming unattended — exactly when they are worth reading.
void setSonicLogSink(SonicLogSink? sink) => _sink = sink;

/// Lightweight tagged logging for the signaling/WebRTC flow.
///
/// Uses [debugPrint], which still emits in release builds (unlike `assert`),
/// so the output shows up in `adb logcat` as `I/flutter` lines prefixed with
/// `[SonicRelay/<tag>]`. Filter with: `adb logcat | grep SonicRelay`.
void sonicLog(String tag, String message) {
  debugPrint('[SonicRelay/$tag] $message');
  try {
    _sink?.call(tag, message);
  } catch (_) {
    // Diagnostics must never take down the flow they are describing: a full
    // disk or a closed log file has to stay strictly less important than the
    // stream the user is listening to.
  }
}
