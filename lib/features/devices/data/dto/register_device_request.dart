class RegisterDeviceRequest {
  const RegisterDeviceRequest({
    required this.name,
    required this.type,
    required this.platform,
    this.publicKey,
  });

  final String name;
  final String type;
  final String platform;
  final String? publicKey;

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type,
    'platform': platform,
    'publicKey': publicKey,
  };
}
