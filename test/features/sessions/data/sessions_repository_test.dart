import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/env/app_config.dart';
import 'package:sonic_relay/features/devices/data/devices_repository.dart';
import 'package:sonic_relay/features/devices/domain/device.dart';
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

class FakeDevicesRepository implements DevicesRepository {
  String? deviceId = 'viewer-device';

  @override
  Future<String?> readCurrentDeviceId() async => deviceId;

  @override
  Future<Device> ensureCurrentDevice({required String platform}) =>
      throw UnimplementedError();

  @override
  Future<List<Device>> listDevices() => throw UnimplementedError();
}

DioException dioFailure(int status, String code) {
  final options = RequestOptions(path: '/api/sessions/join');
  return DioException(
    requestOptions: options,
    response: Response<Map<String, Object?>>(
      requestOptions: options,
      statusCode: status,
      data: {'code': code},
    ),
  );
}

void main() {
  late FakeSessionsApi api;
  late FakeDevicesRepository devices;
  late SessionsRepository repository;

  setUp(() {
    api = FakeSessionsApi();
    devices = FakeDevicesRepository();
    repository = SessionsRepository(
      api: api,
      devicesRepository: devices,
      config: const AppConfig(
        apiBaseUrl: 'http://api.example',
        webSocketBaseUrl: 'ws://api.example',
      ),
    );
  });

  test('joins with normalized code and registered viewer device', () async {
    final session = await repository.join(' abc123 ');

    expect(api.request?.code, 'ABC123');
    expect(api.request?.deviceId, 'viewer-device');
    expect(session.sessionId, 'session-1');
    expect(session.signalingUrl, Uri.parse('ws://api.example/ws/signaling'));
    expect(repository.currentSession, same(session));
  });

  test('requires a registered viewer device before calling the API', () async {
    devices.deviceId = null;

    await expectLater(
      repository.join('ABC123'),
      throwsA(
        isA<SessionsFailure>().having(
          (failure) => failure.kind,
          'kind',
          SessionsFailureKind.missingDevice,
        ),
      ),
    );
    expect(api.request, isNull);
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
