import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/sonic_relay_app.dart';
import 'package:sonic_relay/features/listener/presentation/listener_page.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_page.dart';
import 'package:sonic_relay/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('uses a dark Material 3 theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SonicRelayApp()));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(materialApp.theme?.brightness, Brightness.dark);
  });

  testWidgets('login presents branding and navigates to join session', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SonicRelayApp()));

    expect(find.text('Hear every detail.'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter session code'), findsOneWidget);
    expect(find.textContaining('Windows publisher'), findsOneWidget);
  });

  testWidgets('feature pages show presentation-only status content', (
    tester,
  ) async {
    Future<void> pumpPage(Widget page) async {
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: page),
      );
    }

    await pumpPage(const JoinSessionPage());
    expect(find.text('Join stream'), findsOneWidget);

    await pumpPage(const ListenerPage());
    expect(find.text('Audio monitor'), findsOneWidget);
    expect(find.text('Latency'), findsOneWidget);
    expect(find.text('ICE state'), findsOneWidget);

    await pumpPage(const SettingsPage());
    expect(find.text('API environment'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('login fits a common small Android viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: SonicRelayApp()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
