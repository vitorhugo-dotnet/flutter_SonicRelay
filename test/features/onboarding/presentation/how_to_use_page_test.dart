import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/onboarding/domain/onboarding_content.dart';
import 'package:sonic_relay/features/onboarding/presentation/how_to_use_page.dart';

void main() {
  testWidgets('lists every step and the troubleshooting tips', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HowToUsePage()));

    for (final step in onboardingSteps) {
      expect(find.text(step.title), findsOneWidget);
    }
    expect(find.text('Troubleshooting'), findsOneWidget);
    for (final tip in onboardingTroubleshootingTips) {
      expect(find.text('• $tip'), findsOneWidget);
    }
  });
}
