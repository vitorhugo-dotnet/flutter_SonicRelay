class BootstrapDeviceResponse {
  const BootstrapDeviceResponse({
    required this.deviceId,
    required this.credentialSecret,
    required this.credentialVersion,
  });

  factory BootstrapDeviceResponse.fromJson(Map<String, Object?> json) =>
      BootstrapDeviceResponse(
        deviceId: json['deviceId'] as String,
        credentialSecret: json['credentialSecret'] as String,
        credentialVersion: (json['credentialVersion'] as num).toInt(),
      );

  final String deviceId;
  final String credentialSecret;
  final int credentialVersion;
}
