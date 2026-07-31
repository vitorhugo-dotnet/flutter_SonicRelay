import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/diagnostics/diagnostic_log.dart';
import '../../core/http/auth_interceptor.dart';
import '../../core/http/dio_client.dart';
import '../../core/storage/background_playback_storage.dart';
import '../../core/storage/relay_mode_storage.dart';
import '../../core/storage/secure_token_storage.dart';
import '../../core/storage/server_config_storage.dart';
import '../../features/background/data/foreground_stream_service.dart';
import '../../features/background/presentation/stream_lifecycle_controller.dart';
import '../../features/listener/presentation/listener_view_model.dart';
import '../../core/webrtc/ice_servers_api.dart';
import '../../core/webrtc/ice_servers_repository.dart';
import '../../core/webrtc/rtc_ice_server_config.dart';
import '../../core/webrtc/rtc_peer_connection_factory.dart';
import '../../core/websocket/websocket_client.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/device_identity/data/device_credential_storage.dart';
import '../../features/device_identity/data/device_identity_api.dart';
import '../../features/device_identity/data/device_identity_session.dart';
import '../../features/devices/data/device_id_storage.dart';
import '../../features/devices/data/devices_api.dart';
import '../../features/devices/data/devices_repository.dart';
import '../../features/pairing/data/pairing_api.dart';
import '../../features/pairing/data/pairing_repository.dart';
import '../../features/pairing/domain/device_pairing.dart';
import '../../features/sessions/data/sessions_api.dart';
import '../../features/sessions/data/sessions_repository.dart';
import '../../features/listener/data/audio_receiver_service.dart';
import '../../features/listener/data/webrtc_receiver_service.dart';
import '../../features/signaling/data/signaling_client.dart';
import '../env/app_config.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// The directory DiagnosticLog writes under — resolved once at startup (see
/// main.dart) since path_provider's directory lookup is async and this
/// provider must be synchronous to construct DiagnosticLog eagerly.
final diagnosticsDirectoryProvider = Provider<String>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

final diagnosticLogProvider = Provider<DiagnosticLog>(
  (ref) => DiagnosticLog(ref.watch(diagnosticsDirectoryProvider)),
);

final serverConfigStorageProvider = Provider<ServerConfigStorage>(
  (ref) => ServerConfigStorage(ref.watch(secureStorageProvider)),
);

/// Holds the currently configured server base URL. The initial value is
/// injected at startup via an override in `main()` with the persisted URL
/// (falling back to [AppConfig.defaultServerUrl]). Updating it persists the
/// new URL and rebuilds every provider that depends on [appConfigProvider].
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(
  ServerUrlNotifier.new,
);

class ServerUrlNotifier extends Notifier<String> {
  ServerUrlNotifier([this._initialUrl = AppConfig.defaultServerUrl]);

  final String _initialUrl;

  @override
  String build() => AppConfig.normalizeServerUrl(_initialUrl);

  Future<void> update(String url) async {
    final normalized = AppConfig.normalizeServerUrl(url);
    await ref.read(serverConfigStorageProvider).write(normalized);
    state = normalized;
  }

  Future<void> reset() async {
    await ref.read(serverConfigStorageProvider).clear();
    state = AppConfig.normalizeServerUrl(AppConfig.defaultServerUrl);
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromServerUrl(ref.watch(serverUrlProvider)),
);

final relayModeStorageProvider = Provider<RelayModeStorage>(
  (ref) => RelayModeStorage(ref.watch(secureStorageProvider)),
);

/// Whether ICE is forced to relay-only (TURN). User-controlled and persisted;
/// applied to the next WebRTC negotiation.
final forceRelayProvider = NotifierProvider<ForceRelayNotifier, bool>(
  ForceRelayNotifier.new,
);

class ForceRelayNotifier extends Notifier<bool> {
  ForceRelayNotifier([this._initial = false]);

  final bool _initial;

  @override
  bool build() => _initial;

  Future<void> set(bool value) async {
    await ref.read(relayModeStorageProvider).write(value);
    state = value;
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(ref.watch(secureStorageProvider)),
);

final devicePlatformProvider = Provider<String>(
  (ref) => Platform.operatingSystem,
);

final deviceCredentialStorageProvider = Provider<DeviceCredentialStorage>(
  (ref) => DeviceCredentialStorage(ref.watch(secureStorageProvider)),
);

final deviceIdentityDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
});

final deviceIdentityApiProvider = Provider<DeviceIdentityApi>(
  (ref) => DioDeviceIdentityApi(ref.watch(deviceIdentityDioProvider)),
);

final deviceIdentityInvalidationProvider =
    NotifierProvider<DeviceIdentityInvalidationNotifier, int>(
      DeviceIdentityInvalidationNotifier.new,
    );

class DeviceIdentityInvalidationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void publish() => state += 1;
}

final deviceIdentitySessionProvider = Provider<DeviceIdentitySession>(
  (ref) => DeviceIdentitySession(
    api: ref.watch(deviceIdentityApiProvider),
    storage: ref.watch(deviceCredentialStorageProvider),
    deviceName: 'SonicRelay ${ref.watch(devicePlatformProvider)} viewer',
    platform: ref.watch(devicePlatformProvider),
    onInvalidated: () =>
        ref.read(deviceIdentityInvalidationProvider.notifier).publish(),
  ),
);

enum DeviceReadinessStatus { restoring, deviceSetup, pairingRequired, ready }

class DeviceReadinessState {
  const DeviceReadinessState.restoring()
    : status = DeviceReadinessStatus.restoring,
      errorMessage = null,
      requiresReset = false;

  const DeviceReadinessState.deviceSetup({
    this.errorMessage,
    this.requiresReset = false,
  }) : status = DeviceReadinessStatus.deviceSetup;

  const DeviceReadinessState.pairingRequired()
    : status = DeviceReadinessStatus.pairingRequired,
      errorMessage = null,
      requiresReset = false;

  const DeviceReadinessState.ready()
    : status = DeviceReadinessStatus.ready,
      errorMessage = null,
      requiresReset = false;

  final DeviceReadinessStatus status;
  final String? errorMessage;
  final bool requiresReset;
}

final deviceReadinessProvider =
    NotifierProvider<DeviceReadinessNotifier, DeviceReadinessState>(
      DeviceReadinessNotifier.new,
    );

class DeviceReadinessNotifier extends Notifier<DeviceReadinessState> {
  late DeviceIdentitySession _identitySession;
  late DeviceCredentialStorage _credentialStorage;
  late PairingRepository _pairingRepository;
  Future<void>? _initialization;

  @override
  DeviceReadinessState build() {
    _identitySession = ref.watch(deviceIdentitySessionProvider);
    _credentialStorage = ref.watch(deviceCredentialStorageProvider);
    _pairingRepository = ref.watch(pairingRepositoryProvider);
    ref.listen(deviceIdentityInvalidationProvider, (_, _) {
      requireDeviceSetup('This device identity must be reset.');
    });
    Future<void>.microtask(initialize);
    return const DeviceReadinessState.restoring();
  }

  Future<void> initialize() {
    final existing = _initialization;
    if (existing != null) return existing;

    late final Future<void> current;
    current = _initialize().whenComplete(() {
      if (identical(_initialization, current)) _initialization = null;
    });
    _initialization = current;
    return current;
  }

  Future<void> retry() async {
    final requiresReset = state.requiresReset;
    state = const DeviceReadinessState.restoring();
    if (requiresReset && !await _resetIdentity()) return;
    await initialize();
  }

  Future<void> resetAndInitialize() async {
    state = const DeviceReadinessState.restoring();
    if (!await _resetIdentity()) return;
    await initialize();
  }

  Future<bool> _resetIdentity() async {
    try {
      await _identitySession.reset();
      return true;
    } catch (_) {
      state = const DeviceReadinessState.deviceSetup(
        errorMessage: 'Unable to reset this device. Please retry.',
        requiresReset: true,
      );
      return false;
    }
  }

  void syncPairings(Iterable<DevicePairing> pairings) {
    if (state.status == DeviceReadinessStatus.restoring ||
        state.status == DeviceReadinessStatus.deviceSetup) {
      return;
    }
    _setPairingReadiness(pairings);
  }

  void requireDeviceSetup([String? message]) {
    state = DeviceReadinessState.deviceSetup(
      errorMessage: message,
      requiresReset: true,
    );
  }

  Future<void> _initialize() async {
    try {
      final existingCredential = await _credentialStorage.read();
      if (existingCredential == null) {
        state = const DeviceReadinessState.deviceSetup();
      }

      await _identitySession.accessToken();
      final credential = await _credentialStorage.read();
      if (credential == null) {
        state = const DeviceReadinessState.deviceSetup(
          errorMessage: 'Unable to prepare this device. Please retry.',
        );
        return;
      }

      _setPairingReadiness(await _pairingRepository.list(credential.deviceId));
    } on DeviceCredentialStorageException catch (error) {
      state = DeviceReadinessState.deviceSetup(
        errorMessage: error.message,
        requiresReset: true,
      );
    } on DeviceIdentitySessionInvalidatedException {
      state = const DeviceReadinessState.deviceSetup(
        errorMessage: 'This device identity must be reset.',
        requiresReset: true,
      );
    } on DioException catch (error) {
      state = DeviceReadinessState.deviceSetup(
        errorMessage: 'Unable to prepare this device. Please retry.',
        requiresReset: error.response?.statusCode == 401,
      );
    } on PairingFailure catch (error) {
      state = DeviceReadinessState.deviceSetup(errorMessage: error.message);
    } catch (_) {
      state = const DeviceReadinessState.deviceSetup(
        errorMessage: 'Unable to prepare this device. Please retry.',
      );
    }
  }

  void _setPairingReadiness(Iterable<DevicePairing> pairings) {
    state = pairings.any((pairing) => pairing.status == 'active')
        ? const DeviceReadinessState.ready()
        : const DeviceReadinessState.pairingRequired();
  }
}

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(
    deviceIdentitySession: ref.watch(deviceIdentitySessionProvider),
    replayDio: ref.watch(deviceIdentityDioProvider),
  );
});

final dioProvider = Provider<Dio>((ref) {
  return createDioClient(
    ref.watch(appConfigProvider),
    ref.watch(authInterceptorProvider),
  );
});

final pairingRepositoryProvider = Provider<PairingRepository>(
  (ref) => PairingRepository(api: DioPairingApi(ref.watch(dioProvider))),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => DioAuthApi(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.watch(authApiProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  ),
);

final deviceIdStorageProvider = Provider<DeviceIdStorage>(
  (ref) => SecureDeviceIdStorage(ref.watch(secureStorageProvider)),
);

final devicesApiProvider = Provider<DevicesApi>(
  (ref) => DioDevicesApi(ref.watch(dioProvider)),
);

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(
    api: ref.watch(devicesApiProvider),
    deviceIdStorage: ref.watch(deviceIdStorageProvider),
  ),
);

final sessionsApiProvider = Provider<SessionsApi>(
  (ref) => DioSessionsApi(ref.watch(dioProvider)),
);

final sessionsRepositoryProvider = Provider<SessionsRepository>(
  (ref) => SessionsRepository(
    api: ref.watch(sessionsApiProvider),
    config: ref.watch(appConfigProvider),
  ),
);

final webSocketClientProvider = Provider<WebSocketClient>(
  (ref) => WebSocketClient(
    connector: ioWebSocketConnector,
    diagnosticLog: ref.watch(diagnosticLogProvider),
  ),
);

final signalingClientProvider = Provider<SignalingClient>(
  (ref) => SignalingClient(
    webSocketClient: ref.watch(webSocketClientProvider),
    deviceIdentitySession: ref.watch(deviceIdentitySessionProvider),
    diagnosticLog: ref.watch(diagnosticLogProvider),
  ),
);

final rtcIceServerConfigProvider = Provider<RtcIceServerConfig>(
  (ref) => RtcIceServerConfig.defaults(),
);

final iceServersApiProvider = Provider<IceServersApi>(
  (ref) => DioIceServersApi(ref.watch(dioProvider)),
);

final iceServersRepositoryProvider = Provider<IceServersRepository>(
  (ref) => IceServersRepository(api: ref.watch(iceServersApiProvider)),
);

final rtcPeerConnectionFactoryProvider = Provider<RtcPeerConnectionFactory>(
  (ref) => const FlutterWebRtcPeerConnectionFactory(),
);

final audioReceiverServiceProvider = Provider<AudioReceiverService>(
  (ref) => WebRtcAudioReceiverService(),
);

final webRtcReceiverServiceProvider = Provider<WebRtcReceiverService>((ref) {
  final service = WebRtcReceiverService(
    peerConnectionFactory: ref.watch(rtcPeerConnectionFactoryProvider),
    audioReceiver: ref.watch(audioReceiverServiceProvider),
    iceServers: ref.watch(rtcIceServerConfigProvider),
    iceServersResolver: ref.watch(iceServersRepositoryProvider).resolve,
    forceRelay: () => ref.read(forceRelayProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final backgroundPlaybackStorageProvider = Provider<BackgroundPlaybackStorage>(
  (ref) => BackgroundPlaybackStorage(ref.watch(secureStorageProvider)),
);

/// Whether the viewer keeps audio playing (via the Android foreground service)
/// while the app is backgrounded during an active stream. Persisted; on by
/// default. Seeded at startup by an override in `main()`.
final backgroundPlaybackEnabledProvider =
    NotifierProvider<BackgroundPlaybackNotifier, bool>(
      BackgroundPlaybackNotifier.new,
    );

class BackgroundPlaybackNotifier extends Notifier<bool> {
  BackgroundPlaybackNotifier([this._initial = true]);

  final bool _initial;

  @override
  bool build() => _initial;

  Future<void> set(bool value) async {
    await ref.read(backgroundPlaybackStorageProvider).write(value);
    state = value;
  }
}

/// The platform foreground service: a real `mediaPlayback` service on Android,
/// a no-op everywhere else (and in tests).
final foregroundStreamServiceProvider = Provider<ForegroundStreamService>((
  ref,
) {
  final service = Platform.isAndroid
      ? AndroidForegroundStreamServiceBridge()
      : NoopForegroundStreamService();
  ref.onDispose(service.dispose);
  return service;
});

/// Decides when the foreground service runs. Callbacks are read lazily so this
/// provider never builds the listener view model (avoiding a dependency cycle).
final streamLifecycleControllerProvider = Provider<StreamLifecycleController>((
  ref,
) {
  final controller = StreamLifecycleController(
    service: ref.watch(foregroundStreamServiceProvider),
    keepPlayingInBackground: () => ref.read(backgroundPlaybackEnabledProvider),
    onStopRequested: () => ref.read(listenerViewModelProvider.notifier).leave(),
    onReconnectRequested: () =>
        ref.read(listenerViewModelProvider.notifier).reconnect(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
