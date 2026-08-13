import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/diagnostics/sonic_log.dart';
import 'package:sonic_relay/core/webrtc/ice_servers_api.dart';
import 'package:sonic_relay/core/webrtc/ice_servers_repository.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';
import 'package:sonic_relay/core/webrtc/rtc_ice_server_config.dart';

class _StubIceServersApi implements IceServersApi {
  _StubIceServersApi(this._result);

  IceServersResult _result;
  Object? _error;
  int calls = 0;

  void failWith(Object error) => _error = error;
  set result(IceServersResult value) {
    _result = value;
    _error = null;
  }

  @override
  Future<IceServersResult> fetch() async {
    calls++;
    if (_error != null) throw _error!;
    return _result;
  }
}

IceServersResult _result({
  List<RtcIceServer>? servers,
  required DateTime expiresAt,
}) {
  return IceServersResult(
    config: RtcIceServerConfig(
      servers ??
          const [
            RtcIceServer(
              urls: ['turn:sonicrelay-turn.hugodotnet.dev:3478?transport=udp'],
              username: 'u',
              credential: 'c',
            ),
          ],
    ),
    expiresAt: expiresAt,
  );
}

void main() {
  test('returns the fetched config', () async {
    final now = DateTime.utc(2026);
    final api = _StubIceServersApi(_result(expiresAt: now.add(const Duration(hours: 1))));
    final repo = IceServersRepository(
      api: api,
      now: () => now,
      relayMode: () => RelayModes.automatic,
      coturnOverride: () => null,
    );

    final config = await repo.resolve();

    expect(config.iceServers.single.urls, [
      'turn:sonicrelay-turn.hugodotnet.dev:3478?transport=udp',
    ]);
    expect(api.calls, 1);
  });

  test('caches until 60s before expiresAt', () async {
    var now = DateTime.utc(2026);
    final api = _StubIceServersApi(_result(expiresAt: now.add(const Duration(hours: 1))));
    final repo = IceServersRepository(
      api: api,
      now: () => now,
      relayMode: () => RelayModes.automatic,
      coturnOverride: () => null,
    );

    await repo.resolve();
    now = now.add(const Duration(seconds: 3600 - 60 - 1));
    await repo.resolve();
    expect(api.calls, 1);

    now = now.add(const Duration(seconds: 2));
    await repo.resolve();
    expect(api.calls, 2);
  });

  test(
    'in dev mode, falls back to Google STUN defaults when the fetch fails and no cache exists',
    () async {
      final api = _StubIceServersApi(
        _result(expiresAt: DateTime.utc(2026).add(const Duration(hours: 1))),
      )..failWith(DioException(requestOptions: RequestOptions(path: '/x')));
      final repo = IceServersRepository(
        api: api,
        allowGoogleStunDevFallback: true,
        relayMode: () => RelayModes.automatic,
        coturnOverride: () => null,
      );

      final config = await repo.resolve();

      expect(config.iceServers.single.urls.first, startsWith('stun:'));
    },
  );

  test(
    'in production mode, does not fall back to Google STUN when the fetch fails and no cache exists',
    () async {
      final api = _StubIceServersApi(
        _result(expiresAt: DateTime.utc(2026).add(const Duration(hours: 1))),
      )..failWith(DioException(requestOptions: RequestOptions(path: '/x')));
      final repo = IceServersRepository(
        api: api,
        allowGoogleStunDevFallback: false,
        relayMode: () => RelayModes.automatic,
        coturnOverride: () => null,
      );

      final config = await repo.resolve();

      expect(config.iceServers, isEmpty);
    },
  );

  // Withholding Google STUN in production is deliberate, but the result is a
  // peer connection with no STUN and no TURN: only host candidates, which
  // cannot cross a NAT. That outcome used to be indistinguishable from a
  // healthy resolve in the logs, so a viewer that could never connect looked
  // like a viewer that simply failed.
  test('logs when it resolves with no ICE servers at all', () async {
    final logged = <(String, String)>[];
    setSonicLogSink((tag, message) => logged.add((tag, message)));
    addTearDown(() => setSonicLogSink(null));
    final api = _StubIceServersApi(
      _result(expiresAt: DateTime.utc(2026).add(const Duration(hours: 1))),
    )..failWith(DioException(requestOptions: RequestOptions(path: '/x')));
    final repo = IceServersRepository(
      api: api,
      allowGoogleStunDevFallback: false,
      relayMode: () => RelayModes.automatic,
      coturnOverride: () => null,
    );

    await repo.resolve();

    expect(
      logged.where(
        (entry) => entry.$1 == 'WebRTC' && entry.$2.contains('no ICE servers'),
      ),
      isNotEmpty,
    );
  });

  test('does not log the empty-list warning when servers were resolved', () async {
    final logged = <(String, String)>[];
    setSonicLogSink((tag, message) => logged.add((tag, message)));
    addTearDown(() => setSonicLogSink(null));
    final api = _StubIceServersApi(
      _result(expiresAt: DateTime.utc(2026).add(const Duration(hours: 1))),
    );
    final repo = IceServersRepository(
      api: api,
      allowGoogleStunDevFallback: false,
      relayMode: () => RelayModes.automatic,
      coturnOverride: () => null,
    );

    await repo.resolve();

    expect(
      logged.where((entry) => entry.$2.contains('no ICE servers')),
      isEmpty,
    );
  });

  test('returns the last good cache when a later refresh fails, even in production mode', () async {
    var now = DateTime.utc(2026);
    final api = _StubIceServersApi(_result(expiresAt: now.add(const Duration(hours: 1))));
    final repo = IceServersRepository(
      api: api,
      now: () => now,
      allowGoogleStunDevFallback: false,
      relayMode: () => RelayModes.automatic,
      coturnOverride: () => null,
    );
    await repo.resolve();

    api.failWith(DioException(requestOptions: RequestOptions(path: '/x')));
    now = now.add(const Duration(hours: 2));

    final config = await repo.resolve();
    expect(config.iceServers.single.urls, [
      'turn:sonicrelay-turn.hugodotnet.dev:3478?transport=udp',
    ]);
  });

  test('a coturn override replaces the turn url and keeps the credentials', () async {
    final repository = IceServersRepository(
      api: _StubIceServersApi(
        _result(
          servers: const [
            RtcIceServer(urls: ['stun:backend.example.com:3478']),
            RtcIceServer(
              urls: ['turn:backend.example.com:3478?transport=udp'],
              username: '1700000000:device',
              credential: 'signed-credential',
            ),
          ],
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
      relayMode: () => RelayModes.automatic,
      coturnOverride: () => 'turn:my-relay.example.com:3478?transport=udp',
    );

    final config = await repository.resolve();

    final turn = config.iceServers.firstWhere((s) => s.urls.first.startsWith('turn:'));
    expect(turn.urls.single, 'turn:my-relay.example.com:3478?transport=udp');
    expect(turn.username, '1700000000:device');
    expect(turn.credential, 'signed-credential');
    expect(config.iceServers.any((s) => s.urls.first.startsWith('stun:')), isTrue);
  });

  test('no override passes the backend list through untouched', () async {
    final repository = IceServersRepository(
      api: _StubIceServersApi(
        _result(
          servers: const [
            RtcIceServer(
              urls: ['turn:backend.example.com:3478?transport=udp'],
              username: 'u',
              credential: 'c',
            ),
          ],
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
      relayMode: () => RelayModes.automatic,
      coturnOverride: () => null,
    );

    final config = await repository.resolve();

    expect(config.iceServers.single.urls.single, 'turn:backend.example.com:3478?transport=udp');
  });

  test(
    'a coturn override change between two resolve() calls is picked up on the second call, '
    'with no extra fetch',
    () async {
      var now = DateTime.utc(2026);
      var override = 'turn:old-relay.example.com:3478?transport=udp';
      final api = _StubIceServersApi(
        _result(
          servers: const [
            RtcIceServer(
              urls: ['turn:backend.example.com:3478?transport=udp'],
              username: 'u',
              credential: 'c',
            ),
          ],
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      final repo = IceServersRepository(
        api: api,
        now: () => now,
        relayMode: () => RelayModes.automatic,
        coturnOverride: () => override,
      );

      final first = await repo.resolve();
      expect(first.iceServers.single.urls.single, override);
      expect(api.calls, 1);

      // No time has passed and no fetch happens on the second call — this is the exact
      // cache-hit path a user hits by editing Settings and rejoining within the TURN
      // credential cache window.
      override = 'turn:new-relay.example.com:3478?transport=udp';
      final second = await repo.resolve();

      expect(second.iceServers.single.urls.single, override);
      expect(api.calls, 1);
    },
  );

  test(
    'a relay mode change between two resolve() calls is picked up on the second call, '
    'with no extra fetch',
    () async {
      var now = DateTime.utc(2026);
      var relayMode = RelayModes.automatic;
      final api = _StubIceServersApi(
        _result(
          servers: const [
            RtcIceServer(urls: ['stun:backend.example.com:3478']),
            RtcIceServer(
              urls: ['turn:backend.example.com:3478?transport=udp'],
              username: 'u',
              credential: 'c',
            ),
          ],
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      final repo = IceServersRepository(
        api: api,
        now: () => now,
        relayMode: () => relayMode,
        coturnOverride: () => null,
      );

      final first = await repo.resolve();
      expect(first.iceServers.any((s) => s.urls.first.startsWith('turn:')), isTrue);
      expect(api.calls, 1);

      relayMode = RelayModes.disableFallback;
      final second = await repo.resolve();

      expect(second.iceServers.any((s) => s.urls.first.startsWith('turn:')), isFalse);
      expect(api.calls, 1);
    },
  );

  test(
    'the failure fallback also applies current preferences to the stale raw cache',
    () async {
      var now = DateTime.utc(2026);
      var relayMode = RelayModes.automatic;
      final api = _StubIceServersApi(
        _result(
          servers: const [
            RtcIceServer(urls: ['stun:backend.example.com:3478']),
            RtcIceServer(
              urls: ['turn:backend.example.com:3478?transport=udp'],
              username: 'u',
              credential: 'c',
            ),
          ],
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      final repo = IceServersRepository(
        api: api,
        now: () => now,
        relayMode: () => relayMode,
        coturnOverride: () => null,
      );
      await repo.resolve();

      api.failWith(DioException(requestOptions: RequestOptions(path: '/x')));
      now = now.add(const Duration(hours: 2));
      relayMode = RelayModes.disableFallback;

      final config = await repo.resolve();

      expect(config.iceServers.any((s) => s.urls.first.startsWith('turn:')), isFalse);
      expect(config.iceServers, hasLength(1));
    },
  );

  test('disableFallback drops turn entries client side', () async {
    final repository = IceServersRepository(
      api: _StubIceServersApi(
        _result(
          servers: const [
            RtcIceServer(urls: ['stun:backend.example.com:3478']),
            RtcIceServer(
              urls: ['turn:backend.example.com:3478?transport=udp'],
              username: 'u',
              credential: 'c',
            ),
          ],
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
      relayMode: () => RelayModes.disableFallback,
      coturnOverride: () => null,
    );

    final config = await repository.resolve();

    expect(config.iceServers.any((s) => s.urls.first.startsWith('turn:')), isFalse);
    expect(config.iceServers, hasLength(1));
  });
}
