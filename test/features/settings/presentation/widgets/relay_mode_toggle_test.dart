import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/relay_mode_storage.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';
import 'package:sonic_relay/features/settings/presentation/widgets/relay_mode_toggle.dart';

class _FakeRelayModeStorage extends RelayModeStorage {
  _FakeRelayModeStorage() : super(const FlutterSecureStorage());

  String stored = RelayModes.automatic;
  Object? writeError;

  @override
  Future<String> read() async => stored;

  @override
  Future<void> write(String mode) async {
    if (writeError case final error?) throw error;
    stored = mode;
  }
}

void main() {
  testWidgets('selecting a mode updates the radio group on success', (tester) async {
    final storage = _FakeRelayModeStorage();
    await tester.pumpWidget(_app(storage));

    await tester.tap(find.text('Force relay (TURN only)'));
    await tester.pumpAndSettle();

    final radioGroup = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(radioGroup.groupValue, RelayModes.forceRelay);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed local save shows an error SnackBar and leaves the selection unchanged', (
    tester,
  ) async {
    final storage = _FakeRelayModeStorage()..writeError = Exception('disk full');
    await tester.pumpWidget(_app(storage));

    await tester.tap(find.text('Force relay (TURN only)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the relay mode. Please try again.'),
      findsOneWidget,
    );
    final radioGroup = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(radioGroup.groupValue, RelayModes.automatic);
  });
}

Widget _app(_FakeRelayModeStorage storage) => ProviderScope(
  overrides: [relayModeStorageProvider.overrideWithValue(storage)],
  child: const MaterialApp(
    home: Scaffold(body: RelayModeToggle()),
  ),
);
