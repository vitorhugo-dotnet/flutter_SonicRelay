class DevicePairing {
  const DevicePairing({
    required this.pairingId,
    required this.publisherDeviceId,
    required this.viewerDeviceId,
    required this.status,
    required this.createdAt,
    this.lastUsedAt,
  });

  final String pairingId;
  final String publisherDeviceId;
  final String viewerDeviceId;
  final String status;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  factory DevicePairing.fromJson(Map<String, Object?> json) {
    final pairingId = json['pairingId'];
    final publisherDeviceId = json['publisherDeviceId'];
    final viewerDeviceId = json['viewerDeviceId'];
    final status = json['status'];
    final createdAt = json['createdAt'];
    final lastUsedAt = json['lastUsedAt'];
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
    );
  }
}
