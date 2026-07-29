import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/app/sonic_relay_app.dart';
import 'package:sonic_relay/features/listener/presentation/listener_page.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_page.dart';
import 'package:sonic_relay/features/settings/presentation/settings_page.dart';

ProviderScope testApp({void Function()? onAuthRepositoryConstructed}) =>
    ProviderScope(
      overrides: [
        deviceReadinessProvider.overrideWith(_ReadyReadinessNotifier.new),
        if (onAuthRepositoryConstructed != null)
          authRepositoryProvider.overrideWith((ref) {
            onAuthRepositoryConstructed();
            throw StateError('Account auth must not be active at startup.');
          }),
      ],
      child: const SonicRelayApp(),
    );

void main() {
  testWidgets('uses a dark Material 3 theme', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(materialApp.theme?.brightness, Brightness.dark);
  });

  testWidgets('startup opens device-first join without constructing auth', (
    tester,
  ) async {
    var authRepositoryConstructed = false;
    await tester.pumpWidget(
      testApp(
        onAuthRepositoryConstructed: () => authRepositoryConstructed = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Join stream'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(authRepositoryConstructed, isFalse);
  });

  testWidgets('feature pages show device-first presentation content', (
    tester,
  ) async {
    Future<void> pumpPage(Widget page) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceReadinessProvider.overrideWith(_ReadyReadinessNotifier.new),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: page,
          ),
        ),
      );
    }

    await pumpPage(const JoinSessionPage());
    expect(find.text('Join stream'), findsOneWidget);

    await pumpPage(const ListenerPage());
    expect(find.text('Audio monitor'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('WebRTC / ICE'), findsOneWidget);

    await pumpPage(const SettingsPage());
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Manage pairings'), findsOneWidget);
    expect(find.text('Reset device identity'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Delete account'), findsNothing);
  });

  testWidgets('device-first startup fits a common small Android viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _ReadyReadinessNotifier extends DeviceReadinessNotifier {
  @override
  DeviceReadinessState build() => const DeviceReadinessState.ready();
}
