import 'package:dio/dio.dart';

import '../domain/device_access_token.dart';
import '../domain/device_credential.dart';
import 'device_credential_storage.dart';
import 'device_identity_api.dart';
import 'dto/bootstrap_device_request.dart';
import 'dto/device_token_request.dart';

class DeviceIdentitySessionInvalidatedException implements Exception {
  const DeviceIdentitySessionInvalidatedException();

  @override
  String toString() =>
      'DeviceIdentitySessionInvalidatedException: reset is required.';
}

class DeviceIdentitySession {
  DeviceIdentitySession({
    required DeviceIdentityApi api,
    required DeviceCredentialStorage storage,
    required String deviceName,
    required String platform,
    DateTime Function()? now,
    void Function()? onInvalidated,
  }) : _api = api,
       _storage = storage,
       _deviceName = deviceName,
       _platform = platform,
       _now = now ?? DateTime.now,
       _onInvalidated = onInvalidated;

  static const _deviceType = 'flutter_viewer';
  static const _expiryMargin = Duration(seconds: 30);

  final DeviceIdentityApi _api;
  final DeviceCredentialStorage _storage;
  final String _deviceName;
  final String _platform;
  final DateTime Function() _now;
  final void Function()? _onInvalidated;

  DeviceAccessToken? _cachedToken;
  Future<String>? _inFlight;
  bool _invalidated = false;
  int _generation = 0;

  Future<String> accessToken({bool forceRefresh = false}) {
    if (_invalidated) {
      return Future<String>.error(
        const DeviceIdentitySessionInvalidatedException(),
      );
    }

    final cachedToken = _cachedToken;
    if (!forceRefresh &&
        cachedToken != null &&
        cachedToken.expiresAt.isAfter(_now().add(_expiryMargin))) {
      return Future<String>.value(cachedToken.value);
    }

    final existing = _inFlight;
    if (existing != null) return existing;

    final generation = _generation;
    late final Future<String> shared;
    shared = _exchange(generation).whenComplete(() {
      if (identical(_inFlight, shared)) _inFlight = null;
    });
    _inFlight = shared;
    return shared;
  }

  Future<void> reset() async {
    final generation = ++_generation;
    _invalidated = true;
    _cachedToken = null;
    _inFlight = null;
    await _storage.clear();
    if (generation == _generation) _invalidated = false;
  }

  Future<String> _exchange(int generation) async {
    try {
      return await _exchangeCurrent(generation);
    } catch (_) {
      _ensureCurrent(generation);
      rethrow;
    }
  }

  Future<String> _exchangeCurrent(int generation) async {
    var credential = await _storage.read();
    _ensureCurrent(generation);
    if (credential == null) {
      final bootstrap = await _api.bootstrap(
        BootstrapDeviceRequest(
          name: _deviceName,
          deviceType: _deviceType,
          platform: _platform,
        ),
      );
      _ensureCurrent(generation);
      credential = DeviceCredential(
        deviceId: bootstrap.deviceId,
        credentialSecret: bootstrap.credentialSecret,
        credentialVersion: bootstrap.credentialVersion,
        deviceType: _deviceType,
        platform: _platform,
      );
      await _storage.write(credential);
      _ensureCurrent(generation);
    }

    try {
      final response = await _api.token(
        DeviceTokenRequest(
          deviceId: credential.deviceId,
          credentialSecret: credential.credentialSecret,
        ),
      );
      _ensureCurrent(generation);
      _cachedToken = response.toDomain();
      return response.accessToken;
    } on DioException catch (error) {
      _ensureCurrent(generation);
      if (error.response?.statusCode == 401) {
        _invalidated = true;
        _cachedToken = null;
        try {
          await _storage.clear();
        } catch (_) {
          // Keep the session invalidated. An explicit reset retries cleanup.
        }
        _ensureCurrent(generation);
        _onInvalidated?.call();
        throw const DeviceIdentitySessionInvalidatedException();
      }
      rethrow;
    }
  }

  void _ensureCurrent(int generation) {
    if (generation != _generation) {
      throw const DeviceIdentitySessionInvalidatedException();
    }
  }
}
