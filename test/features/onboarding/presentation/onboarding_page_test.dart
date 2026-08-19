import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/onboarding_storage.dart';
import 'package:sonic_relay/features/onboarding/domain/onboarding_content.dart';
import 'package:sonic_relay/features/onboarding/presentation/onboarding_page.dart';

class _FakeOnboardingStorage extends OnboardingStorage {
  _FakeOnboardingStorage() : super(const FlutterSecureStorage());

  bool stored = false;

  @override
  Future<bool> read() async => stored;

  @override
  Future<void> write(bool value) async => stored = value;
}

Future<ProviderContainer> _pumpOnboarding(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      onboardingStorageProvider.overrideWithValue(_FakeOnboardingStorage()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: OnboardingPage()),
    ),
  );
  return container;
}

void main() {
  testWidgets('starts on the welcome slide with a Skip and Next action', (
    tester,
  ) async {
    await _pumpOnboarding(tester);

    expect(find.text(onboardingSteps.first.title), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skip')), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('skipping marks onboarding completed', (tester) async {
    final container = await _pumpOnboarding(tester);

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), isTrue);
  });

  testWidgets('stepping through every slide ends on Get started', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);

    for (var i = 0; i < onboardingSteps.length - 1; i++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }

    expect(find.text(onboardingSteps.last.title), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(container.read(onboardingCompletedProvider), isFalse);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), isTrue);
  });
}
