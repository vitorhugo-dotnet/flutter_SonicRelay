import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_page.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_view_model.dart';

void main() {
  testWidgets('shows local validation before joining', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: JoinSessionPage())),
    );

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
}
