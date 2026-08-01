import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/env/app_config.dart';
import 'package:sonic_relay/core/http/manual_retry_required_exception.dart';
import 'package:sonic_relay/features/sessions/data/dto/join_session_request.dart';
import 'package:sonic_relay/features/sessions/data/dto/join_session_response.dart';
import 'package:sonic_relay/features/sessions/data/sessions_api.dart';
import 'package:sonic_relay/features/sessions/data/sessions_repository.dart';

class FakeSessionsApi implements SessionsApi {
  JoinSessionRequest? request;
  Object? error;

  @override
  Future<JoinSessionResponse> join(JoinSessionRequest request) async {
    this.request = request;
    if (error case final value?) throw value;
    return const JoinSessionResponse(sessionId: 'session-1', status: 'waiting');
  }
}

DioException dioFailure(int status, String code, {Object? error}) {
  final options = RequestOptions(path: '/api/sessions/join');
  return DioException(
    requestOptions: options,
    response: Response<Map<String, Object?>>(
      requestOptions: options,
      statusCode: status,
      data: {'code': code},
    ),
    error: error,
  );
}

void main() {
  late FakeSessionsApi api;
  late SessionsRepository repository;

  setUp(() {
    api = FakeSessionsApi();
    repository = SessionsRepository(
      api: api,
      config: const AppConfig(
        apiBaseUrl: 'http://api.example',
        webSocketBaseUrl: 'ws://api.example',
      ),
    );
  });

  test('join request serializes only the normalized session code', () async {
    final session = await repository.join(' abc123 ');

    expect(api.request?.toJson(), {'code': 'ABC123'});
    expect(session.sessionId, 'session-1');
    expect(session.signalingUrl, Uri.parse('ws://api.example/ws/signaling'));
    expect(repository.currentSession, same(session));
  });

  test('maps refreshed unsafe 401 to a typed manual retry failure', () async {
    api.error = dioFailure(
      401,
      'unauthorized',
      error: const ManualRetryRequiredException(),
    );

    await expectLater(
      repository.join('ABC123'),
      throwsA(
        isA<SessionsFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              SessionsFailureKind.manualRetry,
            )
            .having(
              (failure) => failure.message,
              'message',
              contains('Retry'),
            ),
      ),
    );
  });

  for (final testCase
      in <({int status, String code, SessionsFailureKind kind})>[
        (
          status: 400,
          code: 'invalid_code',
          kind: SessionsFailureKind.invalidCode,
        ),
        (
          status: 410,
          code: 'expired_code',
          kind: SessionsFailureKind.expiredCode,
        ),
        (
          status: 409,
          code: 'max_viewers_reached',
          kind: SessionsFailureKind.maxViewers,
        ),
      ]) {
    test('maps ${testCase.code} response', () async {
      api.error = dioFailure(testCase.status, testCase.code);

      await expectLater(
        repository.join('ABC123'),
        throwsA(
          isA<SessionsFailure>().having(
            (failure) => failure.kind,
            'kind',
            testCase.kind,
          ),
        ),
      );
    });
  }
}
