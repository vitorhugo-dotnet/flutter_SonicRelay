import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/pairing/presentation/qr_scanner_page.dart';

const validPayload =
    '{"challengeId":"00000000-0000-0000-0000-000000000001","code":"ABC12345"}';

void main() {
  group('scannerErrorMessage', () {
    test('names permission denial so the user knows what to fix', () {
      for (final code in [
        'CameraAccessDenied',
        'CameraAccessDeniedWithoutPrompt',
        'CameraAccessRestricted',
      ]) {
        expect(
          scannerErrorMessage(CameraException(code, 'denied')),
          'Camera permission denied.',
        );
      }
    });

    test('falls back to a generic message for any other failure', () {
      expect(
        scannerErrorMessage(CameraException('cameraNotFound', 'no camera')),
        'Unable to start the camera.',
      );
      expect(
        scannerErrorMessage(Exception('boom')),
        'Unable to start the camera.',
      );
    });
  });

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

  testWidgets('stops for inactive paused detached and resumes safely', (
    tester,
  ) async {
    final controller = _FakeScannerController();
    await tester.pumpWidget(
      MaterialApp(
        home: QrScannerPage(scannerController: controller, onAccepted: (_) {}),
      ),
    );
    expect(controller.startCalls, 1);

    for (final lifecycleState in [
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(lifecycleState);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();
    }

    expect(controller.stopCalls, 3);
    expect(controller.startCalls, 4);
  });

  testWidgets('never restarts after submission or dispose', (tester) async {
    final controller = _FakeScannerController(raw: validPayload);
    await tester.pumpWidget(
      MaterialApp(
        home: QrScannerPage(scannerController: controller, onAccepted: (_) {}),
      ),
    );
    await tester.tap(find.byKey(const Key('scanner-detect')));
    await tester.pump();
    expect(controller.startCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pump();
    expect(controller.startCalls, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    final startsAfterDispose = controller.startCalls;
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pump();

    expect(controller.startCalls, startsAfterDispose);
    expect(controller.disposeCalls, 1);
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
