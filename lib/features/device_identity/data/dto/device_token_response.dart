import '../../domain/device_access_token.dart';

class DeviceTokenResponse {
  const DeviceTokenResponse({
    required this.accessToken,
    required this.expiresAt,
    required this.scopes,
  });

  factory DeviceTokenResponse.fromJson(Map<String, Object?> json) =>
      DeviceTokenResponse(
        accessToken: json['accessToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
        scopes: List<String>.unmodifiable(
          (json['scopes'] as List<Object?>).cast<String>(),
        ),
      );

  final String accessToken;
  final DateTime expiresAt;
  final List<String> scopes;

  DeviceAccessToken toDomain() => DeviceAccessToken(
    value: accessToken,
    expiresAt: expiresAt,
    scopes: scopes,
  );
}
