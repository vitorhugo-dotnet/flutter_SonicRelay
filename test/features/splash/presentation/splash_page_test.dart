import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/splash/presentation/splash_page.dart';

void main() {
  testWidgets('shows the SonicRelay wordmark, tagline and version', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('SonicRelay'), findsOneWidget);
    expect(find.text('SEU PC TOCA · SEU CELULAR OUVE'), findsOneWidget);
    expect(find.text('v1.1.0 · WebRTC + Opus'), findsOneWidget);
  });

  testWidgets(
    'keeps the looping mark/ring/progress animations running without throwing',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashPage()));

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(tester.takeException(), isNull);
    },
  );
}
