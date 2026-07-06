class JoinSessionRequest {
  const JoinSessionRequest({required this.code, required this.deviceId});

  final String code;
  final String deviceId;

  Map<String, Object?> toJson() => {'code': code, 'deviceId': deviceId};
}
