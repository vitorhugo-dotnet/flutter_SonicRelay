import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/theme_mode_storage.dart';

class _FakeThemeModeStorage extends ThemeModeStorage {
  _FakeThemeModeStorage() : super(const FlutterSecureStorage());

  ThemeMode? written;

  @override
  Future<void> write(ThemeMode mode) async => written = mode;
}

void main() {
  test('ThemeModeNotifier defaults to system and persists changes', () async {
    final storage = _FakeThemeModeStorage();
    final container = ProviderContainer(
      overrides: [themeModeStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);

    await container.read(themeModeProvider.notifier).set(ThemeMode.light);

    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(storage.written, ThemeMode.light);
  });

  test('ThemeModeNotifier seeds its state from the persisted value', () {
    final container = ProviderContainer(
      overrides: [
        themeModeProvider.overrideWith(() => ThemeModeNotifier(ThemeMode.dark)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}
