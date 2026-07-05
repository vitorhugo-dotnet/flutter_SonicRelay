import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/widgets/connection_badge.dart';
import 'package:sonic_relay/core/widgets/loading_overlay.dart';
import 'package:sonic_relay/core/widgets/sonic_button.dart';

void main() {
  testWidgets(
    'SonicButton shows progress and disables interaction while busy',
    (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SonicButton(
              label: 'Connect',
              isLoading: true,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SonicButton));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(pressed, isFalse);
    },
  );

  testWidgets('ConnectionBadge renders its semantic state label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectionBadge(
            label: 'Disconnected',
            status: ConnectionStatus.disconnected,
          ),
        ),
      ),
    );

    expect(find.text('Disconnected'), findsOneWidget);
  });

  testWidgets('LoadingOverlay covers content and shows a status label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoadingOverlay(
          isLoading: true,
          message: 'Connecting',
          child: Text('Content'),
        ),
      ),
    );

    expect(find.text('Content'), findsOneWidget);
    expect(find.text('Connecting'), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
  });
}
