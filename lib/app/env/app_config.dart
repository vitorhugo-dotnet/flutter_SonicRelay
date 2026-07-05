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
}
