import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _activeDocs = [
  'README.md',
  'docs/integration-flow.md',
  'docs/flutter-architecture.md',
  'docs/troubleshooting.md',
];

void main() {
  test('active docs contain no account-era viewer contracts', () {
    final combined = _activeDocs
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    final forbidden = <String, RegExp>{
      'account login endpoint': RegExp(r'/auth/login', caseSensitive: false),
      'account refresh endpoint': RegExp(
        r'/auth/refresh',
        caseSensitive: false,
      ),
      'account logout endpoint': RegExp(r'/auth/logout', caseSensitive: false),
      'account logout language': RegExp(
        r'\blog(?:\s|-)?out\b',
        caseSensitive: false,
      ),
      'login route': RegExp(r'`/login`'),
      'legacy join body': RegExp(r'\{code,\s*deviceId\}'),
      'legacy signaling query': RegExp(
        r'ws/signaling[^\n]*deviceId',
        caseSensitive: false,
      ),
      'account bearer scheme': RegExp(r'Authorization:\s*Bearer\b'),
    };

    for (final entry in forbidden.entries) {
      expect(
        combined,
        isNot(matches(entry.value)),
        reason: 'Active docs still contain ${entry.key}.',
      );
    }
  });

  test('active docs pin the Phase 3 device-first contracts', () {
    final combined = _activeDocs
        .map((path) => File(path).readAsStringSync())
        .join('\n');

    expect(combined, contains('Authorization: DeviceBearer'));
    expect(combined, contains('/api/devices/bootstrap'));
    expect(combined, contains('/api/devices/token'));
    expect(combined, contains('/api/pairings/complete'));
    expect(combined, contains('QR'));
    expect(combined.toLowerCase(), contains('manual'));
    expect(
      combined,
      matches(RegExp(r'"code"\s*:\s*"ABC123"')),
      reason: 'Join must document a body containing only the session code.',
    );
    expect(
      combined,
      matches(RegExp(r'only\s+`sessionId`', caseSensitive: false)),
      reason: 'Signaling must document sessionId as its only query parameter.',
    );
  });
}
