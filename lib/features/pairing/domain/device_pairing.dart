class DevicePairing {
  const DevicePairing({
    required this.pairingId,
    required this.publisherDeviceId,
    required this.viewerDeviceId,
    required this.status,
    required this.createdAt,
    this.lastUsedAt,
    this.publisherDeviceName,
    this.viewerDeviceName,
  });

  final String pairingId;
  final String publisherDeviceId;
  final String viewerDeviceId;
  final String status;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  /// Human device names resolved by the backend. Optional: an older backend
  /// omits them, and display code then falls back to the device id.
  final String? publisherDeviceName;
  final String? viewerDeviceName;

  /// Whether the backend supplied a usable publisher machine name.
  bool get hasPublisherDeviceName =>
      publisherDeviceName != null && publisherDeviceName!.trim().isNotEmpty;

  factory DevicePairing.fromJson(Map<String, Object?> json) {
    final pairingId = json['pairingId'];
    final publisherDeviceId = json['publisherDeviceId'];
    final viewerDeviceId = json['viewerDeviceId'];
    final status = json['status'];
    final createdAt = json['createdAt'];
    final lastUsedAt = json['lastUsedAt'];
    final publisherDeviceName = json['publisherDeviceName'];
    final viewerDeviceName = json['viewerDeviceName'];
    if (pairingId is! String ||
        publisherDeviceId is! String ||
        viewerDeviceId is! String ||
        status is! String ||
        createdAt is! String ||
        (lastUsedAt != null && lastUsedAt is! String)) {
      throw const FormatException('Invalid device pairing response.');
    }

    return DevicePairing(
      pairingId: pairingId,
      publisherDeviceId: publisherDeviceId,
      viewerDeviceId: viewerDeviceId,
      status: status,
      createdAt: DateTime.parse(createdAt),
      lastUsedAt: lastUsedAt == null
          ? null
          : DateTime.parse(lastUsedAt as String),
      // Tolerant on purpose: names are additive and must not fail parsing.
      publisherDeviceName: publisherDeviceName is String
          ? publisherDeviceName
          : null,
      viewerDeviceName: viewerDeviceName is String ? viewerDeviceName : null,
    );
  }
}
