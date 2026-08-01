import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/device_credential.dart';

class DeviceCredentialStorageException implements Exception {
  const DeviceCredentialStorageException(this.message);

  final String message;

  @override
  String toString() => 'DeviceCredentialStorageException: $message';
}

class DeviceCredentialStorage {
  const DeviceCredentialStorage(this._storage);

  static const _credentialKey = 'deviceIdentity.credential';
  static const _invalidCredentialMessage = 'Device credential is invalid.';

  final FlutterSecureStorage _storage;

  Future<DeviceCredential?> read() async {
    final encoded = await _storage.read(key: _credentialKey);
    if (encoded == null) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw const DeviceCredentialStorageException(_invalidCredentialMessage);
    }

    if (decoded is! Map<String, dynamic>) {
      throw const DeviceCredentialStorageException(_invalidCredentialMessage);
    }

    final deviceId = decoded['deviceId'];
    final credentialSecret = decoded['credentialSecret'];
    final credentialVersion = decoded['credentialVersion'];
    final deviceType = decoded['deviceType'];
    final platform = decoded['platform'];
    if (deviceId is! String ||
        credentialSecret is! String ||
        credentialVersion is! int ||
        deviceType is! String ||
        platform is! String) {
      throw const DeviceCredentialStorageException(_invalidCredentialMessage);
    }

    final credential = DeviceCredential(
      deviceId: deviceId,
      credentialSecret: credentialSecret,
      credentialVersion: credentialVersion,
      deviceType: deviceType,
      platform: platform,
    );
    _validate(credential);
    return credential;
  }

  Future<void> write(DeviceCredential credential) async {
    _validate(credential);
    await _storage.write(
      key: _credentialKey,
      value: jsonEncode({
        'deviceId': credential.deviceId,
        'credentialSecret': credential.credentialSecret,
        'credentialVersion': credential.credentialVersion,
        'deviceType': credential.deviceType,
        'platform': credential.platform,
      }),
    );
  }

  Future<void> clear() => _storage.delete(key: _credentialKey);

  static void _validate(DeviceCredential credential) {
    if (credential.deviceId.trim().isEmpty ||
        credential.credentialSecret.trim().isEmpty ||
        credential.credentialVersion <= 0 ||
        credential.deviceType.trim().isEmpty ||
        (credential.platform != 'android' && credential.platform != 'ios')) {
      throw const DeviceCredentialStorageException(_invalidCredentialMessage);
    }
  }
}
