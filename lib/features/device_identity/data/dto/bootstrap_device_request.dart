class BootstrapDeviceRequest {
  const BootstrapDeviceRequest({
    required this.name,
    required this.deviceType,
    required this.platform,
  });

  final String name;
  final String deviceType;
  final String platform;

  Map<String, Object?> toJson() => {
    'name': name,
    'deviceType': deviceType,
    'platform': platform,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BootstrapDeviceRequest &&
          name == other.name &&
          deviceType == other.deviceType &&
          platform == other.platform;

  @override
  int get hashCode => Object.hash(name, deviceType, platform);
}
