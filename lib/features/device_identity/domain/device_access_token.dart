class DeviceAccessToken {
  const DeviceAccessToken({
    required this.value,
    required this.expiresAt,
    required this.scopes,
  });

  final String value;
  final DateTime expiresAt;
  final List<String> scopes;
}
