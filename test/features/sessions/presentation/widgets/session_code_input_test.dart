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

  testWidgets(
    'strips a pasted hyphen before the 6-character limit truncates it',
    (tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionCodeInput(onChanged: (value) => changed = value),
          ),
        ),
      );

      // 7 raw characters including the separator. If truncation to 6 raw
      // characters happened before stripping, this would land as 'SR-4F8'
      // -> 'SR4F8' (five characters) instead of the correct 'SR4F8K'.
      await tester.enterText(find.byType(TextField), 'SR-4F8K');

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'SR4F8K',
      );
      expect(changed, 'SR4F8K');
    },
  );

  testWidgets(
    'strips a pasted space separator before the 6-character limit truncates it',
    (tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionCodeInput(onChanged: (value) => changed = value),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'FE23 7F');

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'FE237F',
      );
      expect(changed, 'FE237F');
    },
  );
}
