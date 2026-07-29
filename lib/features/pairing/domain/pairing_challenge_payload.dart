import 'dart:convert';

class PairingChallengePayload {
  const PairingChallengePayload({
    required this.challengeId,
    required this.code,
  });

  final String challengeId;
  final String code;

  static PairingChallengePayload parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Invalid pairing challenge payload.');
    }

    if (decoded is! Map<String, dynamic> ||
        decoded.length != 2 ||
        !decoded.containsKey('challengeId') ||
        !decoded.containsKey('code')) {
      throw const FormatException('Invalid pairing challenge payload.');
    }

    final challengeId = decoded['challengeId'];
    final code = decoded['code'];
    if (challengeId is! String ||
        !_guid.hasMatch(challengeId) ||
        code is! String ||
        code.trim().isEmpty) {
      throw const FormatException('Invalid pairing challenge payload.');
    }

    return PairingChallengePayload(challengeId: challengeId, code: code.trim());
  }

  static final _guid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
}
