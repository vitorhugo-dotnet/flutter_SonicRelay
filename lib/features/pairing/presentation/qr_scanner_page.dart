import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/pairing_challenge_payload.dart';

typedef PairingPayloadCallback = FutureOr<void> Function(String raw);

abstract interface class PairingScannerController {
  Future<void> start();

  Future<void> stop();

  Future<void> dispose();

  Widget buildScanner({required ValueChanged<String?> onDetected});
}

class MobilePairingScannerController implements PairingScannerController {
  MobilePairingScannerController()
    : _controller = MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
      );

  final MobileScannerController _controller;

  @override
  Widget buildScanner({required ValueChanged<String?> onDetected}) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          if (barcode.rawValue case final raw?) {
            onDetected(raw);
            return;
          }
        }
      },
      errorBuilder: (context, error) {
        if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
          return const Center(child: Text('Camera permission denied.'));
        }
        return const Center(child: Text('Unable to start the camera.'));
      },
    );
  }

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Future<void> start() => _controller.start();

  @override
  Future<void> stop() => _controller.stop();
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({
    required this.onAccepted,
    this.onManualFallback,
    this.scannerController,
    super.key,
  });

  final PairingPayloadCallback onAccepted;
  final VoidCallback? onManualFallback;
  final PairingScannerController? scannerController;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver {
  late final PairingScannerController _controller;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.scannerController ?? MobilePairingScannerController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startScanner());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Once a QR frame has been accepted the page is on its way out; leave the
    // scanner alone so a background/foreground cycle during navigation can't
    // race a stray restart back in.
    if (_accepted) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_startScanner());
    } else {
      unawaited(_controller.stop());
    }
  }

  Future<void> _startScanner() async {
    try {
      await _controller.start();
    } catch (_) {
      // The scanner widget renders its permission/start error state. Pairing
      // remains available through the manual fallback below.
    }
  }

  Future<void> _handleDetection(String? raw) async {
    if (_accepted || raw == null) return;
    try {
      PairingChallengePayload.parse(raw);
    } on FormatException {
      return;
    }

    _accepted = true;
    await _controller.stop();
    await widget.onAccepted(raw);
  }

  void _manualFallback() {
    final callback = widget.onManualFallback;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan pairing QR')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _controller.buildScanner(onDetected: _handleDetection),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _manualFallback,
                  child: const Text('Enter manually'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
