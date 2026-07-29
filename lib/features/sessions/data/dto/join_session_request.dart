class JoinSessionRequest {
  const JoinSessionRequest({required this.code});

  final String code;

  Map<String, Object?> toJson() => {'code': code};
}
