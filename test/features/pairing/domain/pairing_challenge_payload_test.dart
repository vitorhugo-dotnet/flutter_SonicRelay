import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/pairing/domain/pairing_challenge_payload.dart';

void main() {
  const validChallengeId = '00000000-0000-0000-0000-000000000001';

  test('accepts exactly challengeId and non-blank code', () {
    final payload = PairingChallengePayload.parse(
      '{"challengeId":"$validChallengeId","code":"ABC12345"}',
    );

    expect(payload.challengeId, validChallengeId);
    expect(payload.code, 'ABC12345');
  });

  for (final raw in <String>[
    'not-json',
    '[]',
    '{}',
    '{"challengeId":"$validChallengeId"}',
    '{"code":"ABC12345"}',
    '{"challengeId":"not-a-guid","code":"ABC12345"}',
    '{"challengeId":"$validChallengeId","code":"   "}',
    '{"challengeId":"$validChallengeId","code":"ABC12345","extra":true}',
    '{"challengeId":"$validChallengeId","code":"ABC12345","credentialSecret":"secret"}',
    '{"challengeId":"$validChallengeId","code":"ABC12345","accessToken":"token"}',
    '{"challengeId":"$validChallengeId","code":"ABC12345","deviceId":"device-1"}',
  ]) {
    test('rejects non-minimal or invalid payload: $raw', () {
      expect(
        () => PairingChallengePayload.parse(raw),
        throwsA(isA<FormatException>()),
      );
    });
  }
}
