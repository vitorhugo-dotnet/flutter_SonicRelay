import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the viewer's appearance (theme) preference so it survives app
/// restarts. Absent (never set, i.e. a new install) reads back as
/// [ThemeMode.system].
class ThemeModeStorage {
  const ThemeModeStorage(this._storage);

  static const _key = 'appearance.themeMode';

  final FlutterSecureStorage _storage;

  Future<ThemeMode> read() async {
    final stored = await _storage.read(key: _key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> write(ThemeMode mode) =>
      _storage.write(key: _key, value: mode.name);
}
