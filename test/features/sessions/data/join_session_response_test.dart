import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/sessions/data/dto/join_session_response.dart';
import 'package:sonic_relay/features/sessions/domain/session_status.dart';

void main() {
  // The backend `POST /api/sessions/join` returns a full StreamSession record
  // and no signaling URL. These tests lock that real contract.
  Map<String, Object?> backendBody({String status = 'waiting'}) => {
    'id': '11111111-1111-1111-1111-111111111111',
    'ownerUserId': '22222222-2222-2222-2222-222222222222',
    'sourceDeviceId': '33333333-3333-3333-3333-333333333333',
    'status': status,
    'maxViewers': 3,
    'codeExpiresAt': '2026-07-06T14:00:00Z',
    'startedAt': null,
    'endedAt': null,
    'createdAt': '2026-07-06T13:50:00Z',
    'code': null,
  };

  test('parses the backend id as the session id', () {
    final response = JoinSessionResponse.fromJson(backendBody());
    expect(response.sessionId, '11111111-1111-1111-1111-111111111111');
    expect(response.status, 'waiting');
  });

  test('builds the domain session with the supplied signaling url', () {
    final signaling = Uri.parse('wss://api.example/ws/signaling');
    final session = JoinSessionResponse.fromJson(
      backendBody(status: 'active'),
    ).toDomain(signaling);

    expect(session.sessionId, '11111111-1111-1111-1111-111111111111');
    expect(session.signalingUrl, signaling);
    expect(session.status, SessionStatus.connected);
  });

  test('throws when the id is missing', () {
    final body = backendBody()..remove('id');
    expect(
      () => JoinSessionResponse.fromJson(body),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a non-ws signaling url', () {
    final response = JoinSessionResponse.fromJson(backendBody());
    expect(
      () => response.toDomain(Uri.parse('https://api.example/ws/signaling')),
      throwsA(isA<FormatException>()),
    );
  });
}
