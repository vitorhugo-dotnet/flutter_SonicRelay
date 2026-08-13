import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/features/pairing/domain/device_pairing.dart';

void main() {
  Map<String, Object?> json({Object? publisherName, Object? viewerName}) => {
    'pairingId': 'pairing-1',
    'publisherDeviceId': 'publisher-1',
    'viewerDeviceId': 'viewer-1',
    'status': 'active',
    'createdAt': '2026-08-13T12:00:00Z',
    'publisherDeviceName': publisherName,
    'viewerDeviceName': viewerName,
  };

  test('parses the device names the backend now returns', () {
    final pairing = DevicePairing.fromJson(
      json(publisherName: 'JCPC38', viewerName: "Vitor's phone"),
    );

    expect(pairing.publisherDeviceName, 'JCPC38');
    expect(pairing.viewerDeviceName, "Vitor's phone");
    expect(pairing.hasPublisherDeviceName, isTrue);
  });

  test('tolerates an older backend that omits the names', () {
    final pairing = DevicePairing.fromJson(json());

    expect(pairing.publisherDeviceName, isNull);
    expect(pairing.hasPublisherDeviceName, isFalse);
  });

  test('a blank name does not count as a usable name', () {
    final pairing = DevicePairing.fromJson(json(publisherName: '  '));

    expect(pairing.hasPublisherDeviceName, isFalse);
  });
}
