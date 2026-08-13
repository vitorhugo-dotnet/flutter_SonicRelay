import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/diagnostics/sonic_log.dart';

void main() {
  tearDown(() => setSonicLogSink(null));

  // sonicLog only ever reached debugPrint, so the categories that explain what
  // the app did in the background — `Background` and `WebRTC` — never made it
  // into the log the user can export. An exported log from a phone that had
  // been streaming for hours therefore showed no foreground-service activity at
  // all, which is indistinguishable from the service never having run.
  test('an installed sink receives the tag and message', () {
    final received = <(String, String)>[];
    setSonicLogSink((tag, message) => received.add((tag, message)));

    sonicLog('Background', 'starting foreground service');

    expect(received, [('Background', 'starting foreground service')]);
  });

  test('clearing the sink stops delivery', () {
    final received = <(String, String)>[];
    setSonicLogSink((tag, message) => received.add((tag, message)));
    setSonicLogSink(null);

    sonicLog('WebRTC', 'peer connection state -> connected');

    expect(received, isEmpty);
  });

  test('a throwing sink never breaks the caller', () {
    setSonicLogSink((tag, message) => throw StateError('disk full'));

    expect(() => sonicLog('WebRTC', 'ice failed'), returnsNormally);
  });
}
