import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/pairing/presentation/qr_scanner_page.dart';

const validPayload =
    '{"challengeId":"00000000-0000-0000-0000-000000000001","code":"ABC12345"}';

void main() {
  testWidgets('starts on open and submits only the first accepted QR frame', (
    tester,
  ) async {
    final controller = _FakeScannerController(raw: validPayload);
    var accepted = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: QrScannerPage(
          scannerController: controller,
          onAccepted: (_) => accepted += 1,
        ),
      ),
    );

    expect(controller.startCalls, 1);
    await tester.tap(find.byKey(const Key('scanner-detect')));
    await tester.tap(find.byKey(const Key('scanner-detect')));
    await tester.pump();

    expect(accepted, 1);
    expect(controller.stopCalls, 1);
  });

  testWidgets('camera denial keeps a manual fallback', (tester) async {
    final controller = _FakeScannerController(permissionDenied: true);
    var manualFallbacks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: QrScannerPage(
          scannerController: controller,
          onAccepted: (_) {},
          onManualFallback: () => manualFallbacks += 1,
        ),
      ),
    );

    expect(find.text('Camera permission denied.'), findsOneWidget);
    expect(find.text('Enter manually'), findsOneWidget);
    await tester.tap(find.text('Enter manually'));
    expect(manualFallbacks, 1);
  });

  testWidgets('disposes the scanner controller with the page', (tester) async {
    final controller = _FakeScannerController();
    await tester.pumpWidget(
      MaterialApp(
        home: QrScannerPage(scannerController: controller, onAccepted: (_) {}),
      ),
    );

    expect(controller.disposeCalls, 0);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(controller.disposeCalls, 1);
  });
}

class _FakeScannerController implements PairingScannerController {
  _FakeScannerController({this.raw, this.permissionDenied = false});

  final String? raw;
  final bool permissionDenied;
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Widget buildScanner({required ValueChanged<String?> onDetected}) {
    return Column(
      children: [
        if (permissionDenied) const Text('Camera permission denied.'),
        ElevatedButton(
          key: const Key('scanner-detect'),
          onPressed: () => onDetected(raw),
          child: const Text('Detect'),
        ),
      ],
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }

  @override
  Future<void> start() async {
    startCalls += 1;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}
