import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/env/app_config.dart';
import 'package:sonic_relay/core/http/manual_retry_required_exception.dart';
import 'package:sonic_relay/features/sessions/data/dto/discoverable_session.dart';
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

  @override
  Future<List<DiscoverableSession>> discover() async => const [];

  @override
  Future<JoinSessionResponse> joinById(String sessionId) async {
    if (error case final value?) throw value;
    return const JoinSessionResponse(sessionId: 'session-1', status: 'waiting');
  }
}

class _StubSessionsApi implements SessionsApi {
  _StubSessionsApi({required this.discoverable});

  final List<DiscoverableSession> discoverable;

  @override
  Future<JoinSessionResponse> join(JoinSessionRequest request) =>
      throw UnimplementedError();

  @override
  Future<JoinSessionResponse> joinById(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<List<DiscoverableSession>> discover() async => discoverable;
}

class _ThrowingSessionsApi implements SessionsApi {
  _ThrowingSessionsApi(this.error);

  final Object error;

  @override
  Future<JoinSessionResponse> join(JoinSessionRequest request) =>
      throw UnimplementedError();

  @override
  Future<JoinSessionResponse> joinById(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<List<DiscoverableSession>> discover() async => throw error;
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

  test('maps 403 not_paired to a pairing failure, not an invalid code', () async {
    api.error = dioFailure(403, 'not_paired');

    await expectLater(
      repository.join('FE237F'),
      throwsA(
        isA<SessionsFailure>().having(
          (failure) => failure.kind,
          'kind',
          SessionsFailureKind.notPaired,
        ),
      ),
    );
  });

  test('discover maps the backend payload', () async {
    final repository = SessionsRepository(
      api: _StubSessionsApi(discoverable: const [
        DiscoverableSession(
          sessionId: '11111111-1111-1111-1111-111111111111',
          publisherDeviceName: 'VITOR-DESKTOP',
          status: 'waiting',
          viewerCount: 0,
          maxViewers: 3,
        ),
      ]),
      config: AppConfig.fromServerUrl('https://example.test'),
    );

    final sessions = await repository.discover();

    expect(sessions.single.publisherDeviceName, 'VITOR-DESKTOP');
    expect(sessions.single.viewerCount, 0);
  });

  test('discover returns an empty list rather than throwing on failure', () async {
    final repository = SessionsRepository(
      api: _ThrowingSessionsApi(
        DioException(requestOptions: RequestOptions(path: '/api/sessions/discoverable')),
      ),
      config: AppConfig.fromServerUrl('https://example.test'),
    );

    expect(await repository.discover(), isEmpty);
  });
}
