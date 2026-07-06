enum DeviceType {
  flutterViewer('flutter_viewer'),
  windowsPublisher('windows_publisher');

  const DeviceType(this.value);

  final String value;

  static DeviceType fromValue(String value) => DeviceType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => throw FormatException('Unknown device type: $value'),
  );
}
