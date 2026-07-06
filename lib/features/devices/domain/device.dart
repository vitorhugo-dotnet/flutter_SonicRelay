import 'device_type.dart';

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.platform,
    required this.publicKey,
    required this.trusted,
    required this.revoked,
    required this.lastSeenAt,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DeviceType type;
  final String platform;
  final String? publicKey;
  final bool trusted;
  final bool revoked;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
}
