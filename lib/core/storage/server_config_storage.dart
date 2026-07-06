import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user-configured server base URL so it survives app restarts.
class ServerConfigStorage {
  const ServerConfigStorage(this._storage);

  static const _serverUrlKey = 'server.baseUrl';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    final value = await _storage.read(key: _serverUrlKey);
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  Future<void> write(String url) =>
      _storage.write(key: _serverUrlKey, value: url);

  Future<void> clear() => _storage.delete(key: _serverUrlKey);
}
