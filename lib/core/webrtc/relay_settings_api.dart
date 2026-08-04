import 'package:dio/dio.dart';

import 'relay_modes.dart';

class RelaySettingsResult {
  const RelaySettingsResult({
    required this.relayMode,
    required this.turnUris,
    required this.hasCustomTurnSecret,
  });

  final String relayMode;
  final List<String> turnUris;
  final bool hasCustomTurnSecret;
}

abstract interface class RelaySettingsApi {
  Future<RelaySettingsResult> fetch();
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris});
}

class DioRelaySettingsApi implements RelaySettingsApi {
  const DioRelaySettingsApi(this._dio);

  final Dio _dio;

  @override
  Future<RelaySettingsResult> fetch() async {
    final response = await _dio.get<Map<String, Object?>>('/api/settings/relay');
    return _parse(response.data ?? const {});
  }

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async {
    final response = await _dio.put<Map<String, Object?>>(
      '/api/settings/relay',
      data: {'relayMode': ?relayMode, 'turnUris': ?turnUris},
    );
    return _parse(response.data ?? const {});
  }

  RelaySettingsResult _parse(Map<String, Object?> data) => RelaySettingsResult(
    relayMode: data['relayMode'] as String? ?? RelayModes.automatic,
    turnUris: (data['turnUris'] as List?)?.whereType<String>().toList() ?? const [],
    hasCustomTurnSecret: data['hasCustomTurnSecret'] as bool? ?? false,
  );
}
