import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/coturn_override_storage.dart';
import 'package:sonic_relay/features/settings/presentation/widgets/coturn_url_field.dart';

/// Avoids the real `FlutterSecureStorage` plugin, which has no platform channel under
/// `flutter test`.
class _FakeCoturnOverrideStorage extends CoturnOverrideStorage {
  _FakeCoturnOverrideStorage() : super(const FlutterSecureStorage());

  String? written;
  bool writeCalled = false;

  @override
  Future<void> write(String? url) async {
    writeCalled = true;
    written = url;
  }
}

ProviderContainer _container({String? initial}) {
  final container = ProviderContainer(
    overrides: [
      coturnOverrideProvider.overrideWith(() => CoturnOverrideNotifier(initial)),
      coturnOverrideStorageProvider.overrideWithValue(_FakeCoturnOverrideStorage()),
    ],
  );
  return container;
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const MaterialApp(home: Scaffold(body: CoturnUrlField())),
);

void main() {
  testWidgets('starts blank with no local override — the backend value is never shown', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('starts pre-filled with a previously-set local override', (tester) async {
    final container = _container(initial: 'turn:my-relay.example.com:3478');
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('turn:my-relay.example.com:3478'), findsOneWidget);
  });

  testWidgets('saving a valid URL sets the local override and persists it', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'turn:my-relay.example.com:3478?transport=udp',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save coturn URL'));
    await tester.pumpAndSettle();

    expect(
      container.read(coturnOverrideProvider),
      'turn:my-relay.example.com:3478?transport=udp',
    );
    final storage =
        container.read(coturnOverrideStorageProvider) as _FakeCoturnOverrideStorage;
    expect(storage.written, 'turn:my-relay.example.com:3478?transport=udp');
    expect(find.text('Coturn URL saved.'), findsOneWidget);
  });

  testWidgets('saving a blank field clears the override', (tester) async {
    final container = _container(initial: 'turn:old-relay.example.com:3478');
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save coturn URL'));
    await tester.pumpAndSettle();

    expect(container.read(coturnOverrideProvider), isNull);
    final storage =
        container.read(coturnOverrideStorageProvider) as _FakeCoturnOverrideStorage;
    expect(storage.written, isNull);
    expect(find.text('Using the server relay.'), findsOneWidget);
  });

  testWidgets('rejects an invalid coturn URL without saving', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-a-turn-url');
    await tester.tap(find.widgetWithText(FilledButton, 'Save coturn URL'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid TURN URL, e.g. turn:your-coturn-server.example.com:3478'),
      findsOneWidget,
    );
    expect(container.read(coturnOverrideProvider), isNull);
    final storage =
        container.read(coturnOverrideStorageProvider) as _FakeCoturnOverrideStorage;
    expect(storage.writeCalled, isFalse);
  });
}
