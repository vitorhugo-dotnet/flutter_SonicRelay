class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.emailConfirmed = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String?,
    emailConfirmed: json['emailConfirmed'] as bool? ?? false,
  );

  final String id;
  final String email;
  final String? displayName;
  final bool emailConfirmed;
}
