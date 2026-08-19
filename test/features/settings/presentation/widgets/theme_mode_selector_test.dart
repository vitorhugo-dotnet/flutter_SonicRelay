import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/theme_mode_storage.dart';
import 'package:sonic_relay/features/settings/presentation/widgets/theme_mode_selector.dart';

class _FakeThemeModeStorage extends ThemeModeStorage {
  _FakeThemeModeStorage() : super(const FlutterSecureStorage());

  ThemeMode stored = ThemeMode.system;
  Object? writeError;

  @override
  Future<void> write(ThemeMode mode) async {
    if (writeError case final error?) throw error;
    stored = mode;
  }
}

void main() {
  testWidgets('selecting a mode updates the radio group on success', (tester) async {
    final storage = _FakeThemeModeStorage();
    await tester.pumpWidget(_app(storage));

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final radioGroup = tester.widget<RadioGroup<ThemeMode>>(
      find.byType(RadioGroup<ThemeMode>),
    );
    expect(radioGroup.groupValue, ThemeMode.light);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed local save shows an error SnackBar and leaves the selection unchanged', (
    tester,
  ) async {
    final storage = _FakeThemeModeStorage()..writeError = Exception('disk full');
    await tester.pumpWidget(_app(storage));

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the appearance setting. Please try again.'),
      findsOneWidget,
    );
    final radioGroup = tester.widget<RadioGroup<ThemeMode>>(
      find.byType(RadioGroup<ThemeMode>),
    );
    expect(radioGroup.groupValue, ThemeMode.system);
  });
}

Widget _app(_FakeThemeModeStorage storage) => ProviderScope(
  overrides: [themeModeStorageProvider.overrideWithValue(storage)],
  child: const MaterialApp(home: Scaffold(body: ThemeModeSelector())),
);
