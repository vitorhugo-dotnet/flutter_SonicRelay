class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.webSocketBaseUrl});

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'SONIC_RELAY_API_URL',
        defaultValue: 'http://localhost:5000',
      ),
      webSocketBaseUrl: String.fromEnvironment(
        'SONIC_RELAY_WS_URL',
        defaultValue: 'ws://localhost:5000',
      ),
    );
  }

  final String apiBaseUrl;
  final String webSocketBaseUrl;

  /// The fixed signaling endpoint (`/ws/signaling`) built from
  /// [webSocketBaseUrl]. The backend returns no signaling URL on join; the
  /// client constructs it here and the signaling client appends the
  /// `sessionId`/`deviceId` query parameters.
  Uri get signalingUri {
    final base = webSocketBaseUrl.endsWith('/')
        ? webSocketBaseUrl.substring(0, webSocketBaseUrl.length - 1)
        : webSocketBaseUrl;
    return Uri.parse('$base/ws/signaling');
  }
}
