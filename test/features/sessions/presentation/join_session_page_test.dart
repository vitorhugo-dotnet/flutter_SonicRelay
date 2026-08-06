import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/features/sessions/data/dto/discoverable_session.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_page.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_view_model.dart';
import 'package:sonic_relay/features/sessions/presentation/widgets/discovered_sessions_list.dart';

Widget _wrap({List<DiscoverableSession> discoverable = const []}) {
  return ProviderScope(
    overrides: [
      discoverableSessionsProvider.overrideWith(
        (ref) => Stream.value(discoverable),
      ),
    ],
    child: const MaterialApp(home: JoinSessionPage()),
  );
}

void main() {
  testWidgets('shows local validation before joining', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Join stream'));
    await tester.pump();

    expect(find.text('Enter a valid session code.'), findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(JoinSessionPage)),
      ).read(joinSessionViewModelProvider).validationMessage,
      'Enter a valid session code.',
    );
  });

  testWidgets('lists discovered sessions below the code field', (tester) async {
    await tester.pumpWidget(_wrap(discoverable: const [
      DiscoverableSession(
        sessionId: '11111111-1111-1111-1111-111111111111',
        publisherDeviceName: 'VITOR-DESKTOP',
        status: 'waiting',
        viewerCount: 0,
        maxViewers: 3,
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('VITOR-DESKTOP'), findsOneWidget);
  });

  testWidgets('renders nothing extra when no session is discovered', (tester) async {
    await tester.pumpWidget(_wrap(discoverable: const []));
    await tester.pumpAndSettle();

    expect(find.byType(DiscoveredSessionsList), findsNothing);
  });
}
