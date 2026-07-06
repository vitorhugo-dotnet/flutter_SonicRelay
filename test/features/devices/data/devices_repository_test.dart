import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/devices/data/device_id_storage.dart';
import 'package:sonic_relay/features/devices/data/devices_api.dart';
import 'package:sonic_relay/features/devices/data/devices_repository.dart';
import 'package:sonic_relay/features/devices/data/dto/device_response.dart';
import 'package:sonic_relay/features/devices/data/dto/register_device_request.dart';
import 'package:sonic_relay/features/devices/domain/device_type.dart';

class FakeDeviceIdStorage implements DeviceIdStorage {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String deviceId) async => value = deviceId;
}

class FakeDevicesApi implements DevicesApi {
  final devices = <String, DeviceResponse>{};
  final registerRequests = <RegisterDeviceRequest>[];

  @override
  Future<DeviceResponse?> get(String deviceId) async => devices[deviceId];

  @override
  Future<List<DeviceResponse>> list() async => devices.values.toList();

  @override
  Future<DeviceResponse> register(RegisterDeviceRequest request) async {
    registerRequests.add(request);
    final response = deviceResponse(id: 'new-device');
    devices[response.id] = response;
    return response;
  }
}

DeviceResponse deviceResponse({String id = 'device-1', bool revoked = false}) =>
    DeviceResponse(
      id: id,
      name: 'Phone',
      type: 'flutter_viewer',
      platform: 'android',
      publicKey: null,
      trusted: true,
      revoked: revoked,
      lastSeenAt: DateTime.utc(2026, 7, 5),
      createdAt: DateTime.utc(2026, 7, 1),
    );

void main() {
  late FakeDeviceIdStorage storage;
  late FakeDevicesApi api;
  late DevicesRepository repository;

  setUp(() {
    storage = FakeDeviceIdStorage();
    api = FakeDevicesApi();
    repository = DevicesRepository(api: api, deviceIdStorage: storage);
  });

  test('maps API device responses to domain devices', () async {
    api.devices['device-1'] = deviceResponse();

    final devices = await repository.listDevices();

    expect(devices, hasLength(1));
    expect(devices.single.id, 'device-1');
    expect(devices.single.type, DeviceType.flutterViewer);
    expect(devices.single.platform, 'android');
    expect(devices.single.trusted, isTrue);
  });

  test('first registration stores the backend-issued device id', () async {
    final device = await repository.ensureCurrentDevice(platform: 'android');

    expect(device.id, 'new-device');
    expect(storage.value, 'new-device');
    expect(api.registerRequests, hasLength(1));
    expect(api.registerRequests.single.type, 'flutter_viewer');
    expect(api.registerRequests.single.platform, 'android');
  });

  test(
    'existing active local device id is reused without registration',
    () async {
      storage.value = 'existing-device';
      api.devices['existing-device'] = deviceResponse(id: 'existing-device');

      final device = await repository.ensureCurrentDevice(platform: 'android');

      expect(device.id, 'existing-device');
      expect(api.registerRequests, isEmpty);
      expect(storage.value, 'existing-device');
    },
  );

  test(
    'missing local device record is replaced by a new registration',
    () async {
      storage.value = 'deleted-device';

      final device = await repository.ensureCurrentDevice(platform: 'ios');

      expect(device.id, 'new-device');
      expect(storage.value, 'new-device');
      expect(api.registerRequests.single.platform, 'ios');
    },
  );
}
