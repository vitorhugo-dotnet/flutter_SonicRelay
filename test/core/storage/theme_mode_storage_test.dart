import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/storage/theme_mode_storage.dart';

void main() {
  const secureStorage = FlutterSecureStorage();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('defaults to system with nothing stored', () async {
    expect(await const ThemeModeStorage(secureStorage).read(), ThemeMode.system);
  });

  test('round trips a written theme mode', () async {
    const storage = ThemeModeStorage(secureStorage);

    await storage.write(ThemeMode.light);

    expect(await storage.read(), ThemeMode.light);
  });

  test('round trips dark', () async {
    const storage = ThemeModeStorage(secureStorage);

    await storage.write(ThemeMode.dark);

    expect(await storage.read(), ThemeMode.dark);
  });
}
