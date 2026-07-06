import '../../domain/device.dart';
import '../../domain/device_type.dart';

class DeviceResponse {
  const DeviceResponse({
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

  factory DeviceResponse.fromJson(Map<String, Object?> json) => DeviceResponse(
    id: json['id']! as String,
    name: json['name']! as String,
    type: json['type']! as String,
    platform: json['platform']! as String,
    publicKey: json['publicKey'] as String?,
    trusted: json['trusted']! as bool,
    revoked: json['revoked']! as bool,
    lastSeenAt: _dateTimeOrNull(json['lastSeenAt']),
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  final String id;
  final String name;
  final String type;
  final String platform;
  final String? publicKey;
  final bool trusted;
  final bool revoked;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  Device toDomain() => Device(
    id: id,
    name: name,
    type: DeviceType.fromValue(type),
    platform: platform,
    publicKey: publicKey,
    trusted: trusted,
    revoked: revoked,
    lastSeenAt: lastSeenAt,
    createdAt: createdAt,
  );

  static DateTime? _dateTimeOrNull(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
