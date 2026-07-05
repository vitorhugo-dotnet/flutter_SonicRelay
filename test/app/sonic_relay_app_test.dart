import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/sonic_relay_app.dart';

void main() {
  testWidgets('boots on login and navigates to join session', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SonicRelayApp()));

    expect(find.text('Login'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Join a session'));
    await tester.pumpAndSettle();

    expect(find.text('Join session'), findsOneWidget);
  });
}
