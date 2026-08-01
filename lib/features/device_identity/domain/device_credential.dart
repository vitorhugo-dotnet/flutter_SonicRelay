class DeviceCredential {
  const DeviceCredential({
    required this.deviceId,
    required this.credentialSecret,
    required this.credentialVersion,
    required this.deviceType,
    required this.platform,
  });

  final String deviceId;
  final String credentialSecret;
  final int credentialVersion;
  final String deviceType;
  final String platform;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceCredential &&
          deviceId == other.deviceId &&
          credentialSecret == other.credentialSecret &&
          credentialVersion == other.credentialVersion &&
          deviceType == other.deviceType &&
          platform == other.platform;

  @override
  int get hashCode => Object.hash(
    deviceId,
    credentialSecret,
    credentialVersion,
    deviceType,
    platform,
  );
}
