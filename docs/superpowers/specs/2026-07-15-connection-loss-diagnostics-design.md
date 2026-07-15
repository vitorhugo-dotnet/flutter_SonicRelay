# Connection-Loss Diagnostics: File Logging, Export, Clear, and Retention

## Goal

The viewer still loses connection when minimized, backgrounded, or closed, and today's
only logging is `sonicLog()` — a `debugPrint` wrapper that never persists and is only
visible through `adb logcat`. Build a `SonicRelay.Windows`-equivalent diagnostics
component: a persisted, structured, redacted log the user can export from the app and
clear, with automatic cleanup so it never grows unbounded.

## Scope

In scope: a new file-backed logger replacing `sonic_log.dart`'s call sites, a diagnostics
screen with Export/Clear actions, 3-day retention, and new log events at the transitions
most likely to correlate with a loss (app lifecycle background/foreground, WebRTC/ICE
connection state changes, reconnect attempts, ICE restarts, and the concrete reason the
signaling WebSocket closed). Out of scope: changing the reconnection behavior itself
(jitter/backoff and ICE-restart-on-reconnect already exist) and any server-side change
(tracked separately in `dotnet_SonicRelay`).

## Architecture

New `lib/core/diagnostics/` module, mirroring the shape already proven in
`windows_SonicRelay`'s `DiagnosticLog`:

- `DiagnosticEvent` — timestamp, category, message, bounded string properties (a simple
  Dart class with `toJson`/`fromJson`).
- `DiagnosticLog` — singleton-ish service (constructed once, injected via existing DI/
  provider setup) that keeps the last 100 events in memory and appends each as one JSON
  line to `<applicationSupportDirectory>/logs/viewer-yyyyMMdd.jsonl`
  (`path_provider`'s `getApplicationSupportDirectory()`, consistent with existing
  platform-appropriate, app-scoped storage — no external storage permission needed).
  Writes are serialized through a lock (a simple `Future` chain, since Dart has no
  built-in mutex) so concurrent writers can't interleave lines.
- `DiagnosticRedactor` — ports the Windows redactor's rules: strip bearer tokens, JWT-like
  strings, SDP bodies, ICE candidate strings, and email addresses from both keys and
  values before they reach memory or disk.
- Retention: on construction, delete `viewer-*.jsonl` files older than 3 days in the log
  directory, best-effort (errors are swallowed — diagnostics must never crash the app).
- `clear()`: deletes all `viewer-*.jsonl` files and empties the in-memory buffer.

`sonicLog(tag, message)` in `sonic_log.dart` is replaced by calls into `DiagnosticLog`
(keeping `debugPrint` in debug builds only, so local development output is unchanged).
Call sites needing an update: `signaling_client.dart`, `listener_connection_state.dart`,
`webrtc_receiver_service.dart`, `stream_lifecycle_controller.dart`,
`foreground_stream_service.dart` — each already logs the moments that matter (connect,
disconnect, reconnect, ICE state); they gain a `reason` property on disconnect/close
events instead of a free-text message, using the same bounded enum the Windows and API
sides use (`normal`, `timeout`, `transport-error`, `server-closed`, `cancelled`).

App lifecycle transitions (`AppLifecycleState.paused/resumed/detached`) get a dedicated
`app-lifecycle` category event, since that's the single biggest suspect for "loses
connection when minimized/closed" on mobile.

## UI

A Diagnostics screen (new or extending an existing settings/debug screen if one exists)
shows recent events and two buttons: **Export** (writes the current log file, or a
combined export of the last N days, to a location shareable via `share_plus`, matching
how the Windows app treats export as "produce something attachable to a support
request") and **Clear** (destructive, behind a confirmation dialog, matching the Windows
UX).

## Data and safety

Same redaction guarantee as Windows: no tokens, SDP, ICE candidates, or emails ever reach
the log file. `reason` properties are drawn from a fixed enum, never raw exception text.

## Verification

Unit tests cover: redaction removes each sensitive pattern, retention deletes only files
older than the threshold, `clear()` empties both file(s) and in-memory buffer, and log
lines round-trip through JSON. A manual pass backgrounds the app during an active session
and confirms an `app-lifecycle` event and (if the connection drops) a `signaling-closed`
event with a correct `reason` both appear in the exported log.
