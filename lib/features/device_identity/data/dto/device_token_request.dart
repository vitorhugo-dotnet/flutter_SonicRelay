class DeviceTokenRequest {
  const DeviceTokenRequest({
    required this.deviceId,
    required this.credentialSecret,
  });

  final String deviceId;
  final String credentialSecret;

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'credentialSecret': credentialSecret,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceTokenRequest &&
          deviceId == other.deviceId &&
          credentialSecret == other.credentialSecret;

  @override
  int get hashCode => Object.hash(deviceId, credentialSecret);
}
