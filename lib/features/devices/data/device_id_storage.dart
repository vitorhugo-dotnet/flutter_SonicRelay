import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DeviceIdStorage {
  Future<String?> read();
  Future<void> write(String deviceId);
  Future<void> clear();
}

class SecureDeviceIdStorage implements DeviceIdStorage {
  const SecureDeviceIdStorage(this._storage);

  static const _deviceIdKey = 'devices.currentDeviceId';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _deviceIdKey);

  @override
  Future<void> write(String deviceId) =>
      _storage.write(key: _deviceIdKey, value: deviceId);

  @override
  Future<void> clear() => _storage.delete(key: _deviceIdKey);
}
