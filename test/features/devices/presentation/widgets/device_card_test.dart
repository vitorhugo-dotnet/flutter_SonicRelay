import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/devices/domain/device.dart';
import 'package:sonic_relay/features/devices/domain/device_type.dart';
import 'package:sonic_relay/features/devices/presentation/widgets/device_card.dart';

void main() {
  testWidgets('renders device identity and status', (tester) async {
    final device = Device(
      id: 'device-1',
      name: 'Living room phone',
      type: DeviceType.flutterViewer,
      platform: 'android',
      publicKey: null,
      trusted: true,
      revoked: false,
      lastSeenAt: DateTime.utc(2026, 7, 5),
      createdAt: DateTime.utc(2026, 7, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: DeviceCard(device: device, isCurrent: true)),
      ),
    );

    expect(find.text('Living room phone'), findsOneWidget);
    expect(find.text('Android · Flutter viewer'), findsOneWidget);
    expect(find.text('Current device'), findsOneWidget);
    expect(find.text('Trusted'), findsOneWidget);
  });
}
