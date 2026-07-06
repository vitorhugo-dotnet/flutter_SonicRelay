import 'package:dio/dio.dart';

import '../domain/device.dart';
import '../domain/device_type.dart';
import 'device_id_storage.dart';
import 'devices_api.dart';
import 'dto/register_device_request.dart';

class DevicesFailure implements Exception {
  const DevicesFailure(this.message);
  final String message;
}

class DevicesRepository {
  const DevicesRepository({
    required DevicesApi api,
    required DeviceIdStorage deviceIdStorage,
  }) : _api = api,
       _deviceIdStorage = deviceIdStorage;

  final DevicesApi _api;
  final DeviceIdStorage _deviceIdStorage;

  Future<String?> readCurrentDeviceId() => _deviceIdStorage.read();

  Future<Device> ensureCurrentDevice({required String platform}) async {
    if (platform != 'android' && platform != 'ios') {
      throw const DevicesFailure(
        'Device registration is supported only on Android and iOS.',
      );
    }

    try {
      final storedId = await _deviceIdStorage.read();
      if (storedId != null) {
        final existing = await _api.get(storedId);
        if (existing != null && !existing.revoked) return existing.toDomain();
        await _deviceIdStorage.clear();
      }

      final response = await _api.register(
        RegisterDeviceRequest(
          name: platform == 'ios'
              ? 'SonicRelay iOS Viewer'
              : 'SonicRelay Android Viewer',
          type: DeviceType.flutterViewer.value,
          platform: platform,
        ),
      );
      await _deviceIdStorage.write(response.id);
      return response.toDomain();
    } on DevicesFailure {
      rethrow;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        throw const DevicesFailure(
          'Your account cannot register this device. Sign in again.',
        );
      }
      throw const DevicesFailure(
        'Unable to register this device. Check your connection and retry.',
      );
    } on FormatException {
      throw const DevicesFailure('The server returned invalid device data.');
    }
  }

  Future<List<Device>> listDevices() async {
    try {
      return (await _api.list()).map((item) => item.toDomain()).toList();
    } on DioException {
      throw const DevicesFailure(
        'Unable to load devices. Check your connection and retry.',
      );
    } on FormatException {
      throw const DevicesFailure('The server returned invalid device data.');
    }
  }
}
