import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/app/env/app_config.dart';
import 'package:sonic_relay/features/settings/presentation/widgets/privacy_policy_link.dart';

Future<void> _pump(
  WidgetTester tester,
  Future<bool> Function(Uri) launcher,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [externalLinkLauncherProvider.overrideWithValue(launcher)],
      child: const MaterialApp(
        home: Scaffold(body: PrivacyPolicyLink()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the policy URL points at the published policy page', () {
    // Play requires the in-app link and the store listing to resolve to the
    // same published policy; a drifting URL is a listing rejection.
    expect(
      AppConfig.privacyPolicyUrl,
      'https://hugodotnet.dev/sonicrelay/privacy-policy',
    );
  });

  testWidgets('tapping the link opens the published privacy policy', (
    tester,
  ) async {
    final opened = <Uri>[];

    await _pump(tester, (uri) async {
      opened.add(uri);
      return true;
    });
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse(AppConfig.privacyPolicyUrl)]);
  });

  testWidgets('the URL is shown as selectable text when nothing can open it', (
    tester,
  ) async {
    // A device with no browser must still be able to reach the policy, so the
    // failure path exposes the address instead of silently doing nothing.
    await _pump(tester, (uri) async => false);

    expect(find.byType(SelectableText), findsNothing);

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(SelectableText, AppConfig.privacyPolicyUrl),
      findsOneWidget,
    );
  });

  testWidgets('a launcher that throws is treated as a failure to open', (
    tester,
  ) async {
    await _pump(tester, (uri) async => throw Exception('no activity found'));

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(SelectableText, AppConfig.privacyPolicyUrl),
      findsOneWidget,
    );
  });
}
