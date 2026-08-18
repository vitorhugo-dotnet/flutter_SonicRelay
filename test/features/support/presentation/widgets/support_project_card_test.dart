import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/app/env/app_config.dart';
import 'package:sonic_relay/features/support/presentation/widgets/support_project_card.dart';

Future<void> _pump(
  WidgetTester tester,
  Future<bool> Function(Uri) launcher, {
  bool compact = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [externalLinkLauncherProvider.overrideWithValue(launcher)],
      child: MaterialApp(
        home: Scaffold(body: SupportProjectCard(compact: compact)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the donation URL points at the project Buy Me a Coffee page', () {
    // The page funds the relay/TURN infrastructure the app depends on; a
    // drifting URL silently sends supporters nowhere.
    expect(
      AppConfig.donationUrl,
      'https://www.buymeacoffee.com/vitorhugo1207',
    );
  });

  testWidgets('tapping the button opens the donation page', (tester) async {
    final opened = <Uri>[];

    await _pump(tester, (uri) async {
      opened.add(uri);
      return true;
    });
    await tester.tap(find.text('Buy me a coffee'));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse(AppConfig.donationUrl)]);
  });

  testWidgets('the full card explains why the project needs support', (
    tester,
  ) async {
    await _pump(tester, (uri) async => true);

    expect(
      find.textContaining('servers', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the compact variant drops the explanation but keeps the button',
      (tester) async {
    // Settings already carries its own footer copy; repeating the pitch there
    // turns the screen into an appeal instead of a settings screen.
    await _pump(tester, (uri) async => true, compact: true);

    expect(find.textContaining('servers', findRichText: true), findsNothing);
    expect(find.text('Buy me a coffee'), findsOneWidget);
  });

  testWidgets('the URL is shown as selectable text when nothing can open it', (
    tester,
  ) async {
    // A device with no browser must still be able to reach the page by hand.
    await _pump(tester, (uri) async => false);

    expect(find.byType(SelectableText), findsNothing);

    await tester.tap(find.text('Buy me a coffee'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(SelectableText, AppConfig.donationUrl),
      findsOneWidget,
    );
  });

  testWidgets('a launcher that throws is treated as a failure to open', (
    tester,
  ) async {
    await _pump(tester, (uri) async => throw Exception('no activity found'));

    await tester.tap(find.text('Buy me a coffee'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(SelectableText, AppConfig.donationUrl),
      findsOneWidget,
    );
  });
}
