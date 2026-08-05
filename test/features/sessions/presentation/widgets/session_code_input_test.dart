import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/sessions/presentation/widgets/session_code_input.dart';

void main() {
  testWidgets('renders typed session code in uppercase', (tester) async {
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionCodeInput(
            onChanged: (value) => changed = value,
            errorText: 'Check this code.',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'fe237f');

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'FE237F',
    );
    expect(find.text('Check this code.'), findsOneWidget);
    expect(changed, 'FE237F');
  });
}
