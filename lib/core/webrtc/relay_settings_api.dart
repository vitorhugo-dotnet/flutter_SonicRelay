import 'package:dio/dio.dart';

/// The user's relay preferences as stored by the backend. The backend resolves
/// them per device across its active pairings (latest write wins), which is
/// what keeps a coturn override made here in sync with the paired desktop and
/// vice versa. The response never contains the provider's own TURN
/// configuration — an empty [turnUris] means "the backend's relay is in use"
/// without naming it.
class RelaySettings {
  const RelaySettings({required this.relayMode, required this.turnUris});

  final String relayMode;
  final List<String> turnUris;

  factory RelaySettings.fromJson(Map<String, Object?> json) {
    final relayMode = json['relayMode'];
    final turnUris = json['turnUris'];
    return RelaySettings(
      relayMode: relayMode is String ? relayMode : 'automatic',
      turnUris: turnUris is List
          ? turnUris.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

class RelaySettingsApi {
  RelaySettingsApi(this._dio);

  final Dio _dio;

  Future<RelaySettings> fetch() async {
    final response = await _dio.get<Map<String, Object?>>(
      '/api/settings/relay',
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty relay settings response.');
    }
    return RelaySettings.fromJson(data);
  }

  Future<void> update({String? relayMode, List<String>? turnUris}) =>
      _dio.put<void>(
        '/api/settings/relay',
        data: {'relayMode': ?relayMode, 'turnUris': ?turnUris},
      );
}
