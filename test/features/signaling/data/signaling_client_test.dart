import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/websocket/websocket_client.dart';
import 'package:sonic_relay/features/device_identity/data/device_identity_session.dart';
import 'package:sonic_relay/features/sessions/domain/stream_session.dart';
import 'package:sonic_relay/features/signaling/data/signaling_client.dart';
import 'package:sonic_relay/features/signaling/domain/signaling_message_type.dart';

class FakeWebSocketConnection implements WebSocketConnection {
  final _controller = StreamController<dynamic>.broadcast();
  final List<String> sent = [];
  bool closed = false;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void add(String data) => sent.add(data);

  @override
  Future<void> close() async {
    closed = true;
    await _controller.close();
  }

  void emit(String data) => _controller.add(data);
}

class MutableDeviceIdentitySession implements DeviceIdentitySession {
  String token = 'token-abc';

  final List<bool> forceRefreshes = [];
  final List<Object> errors = [];

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    forceRefreshes.add(forceRefresh);
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return token;
  }

  @override
  Future<void> reset() async {}
}

class SupersededDeviceIdentitySession implements DeviceIdentitySession {
  final firstStarted = Completer<void>();
  final firstToken = Completer<String>();
  var calls = 0;

  @override
  Future<String> accessToken({bool forceRefresh = false}) {
    calls++;
    if (calls == 1) {
      firstStarted.complete();
      return firstToken.future;
    }
    return Future<String>.value('token-2');
  }

  @override
  Future<void> reset() async {}
}

class ManualTimer implements Timer {
  ManualTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}

Timer _instantTimer(Duration delay, void Function() callback) =>
    Timer(Duration.zero, callback);

Map<String, Object?> _decode(String raw) =>
    jsonDecode(raw) as Map<String, Object?>;

void main() {
  late List<Uri> requestedUris;
  late List<Map<String, String>> requestedHeaders;
  late FakeWebSocketConnection connection;
  late SignalingClient signalingClient;
  late StreamSession session;
  late MutableDeviceIdentitySession identity;

  setUp(() {
    requestedUris = [];
    requestedHeaders = [];
    final webSocketClient = WebSocketClient(
      connector: (uri, headers) async {
        requestedUris.add(uri);
        requestedHeaders.add(headers);
        connection = FakeWebSocketConnection();
        return connection;
      },
      scheduleTimer: _instantTimer,
    );
    identity = MutableDeviceIdentitySession();
    signalingClient = SignalingClient(
      webSocketClient: webSocketClient,
      deviceIdentitySession: identity,
    );
    session = StreamSession(
      sessionId: 'session-1',
      signalingUrl: Uri.parse(
        'wss://stream.example/ws/signaling?deviceId=legacy&unexpected=value',
      ),
    );
  });

  tearDown(() => signalingClient.dispose());

  test('connects with only sessionId and DeviceBearer auth', () async {
    await signalingClient.connect(session: session);
    await Future<void>.delayed(Duration.zero);

    expect(requestedUris, hasLength(1));
    final uri = requestedUris.single;
    expect(uri.queryParameters, {'sessionId': 'session-1'});
    expect(requestedHeaders.single['Authorization'], 'DeviceBearer token-abc');
  });

  test('reconnect obtains a fresh DeviceBearer token', () async {
    await signalingClient.connect(session: session);
    await Future<void>.delayed(Duration.zero);
    identity.token = 'token-2';

    await connection.close();
    for (var i = 0; i < 6 && requestedHeaders.length < 2; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(requestedHeaders, hasLength(2));
    expect(requestedHeaders[0]['Authorization'], 'DeviceBearer token-abc');
    expect(requestedHeaders[1]['Authorization'], 'DeviceBearer token-2');
    expect(identity.forceRefreshes, [false, true]);
  });

  test('transient token failure retries and then connects', () async {
    identity.errors.add(Exception('token temporarily unavailable'));
    identity.token = 'token-2';

    await signalingClient.connect(session: session);
    for (var i = 0; i < 6 && requestedHeaders.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(identity.forceRefreshes, [false, true]);
    expect(requestedHeaders.single['Authorization'], 'DeviceBearer token-2');
  });

  test('leave cancels retry after a transient token failure', () async {
    final timers = <ManualTimer>[];
    final localIdentity = MutableDeviceIdentitySession()
      ..errors.add(Exception('token temporarily unavailable'));
    var connectorCalls = 0;
    final webSocketClient = WebSocketClient(
      connector: (uri, headers) async {
        connectorCalls++;
        return FakeWebSocketConnection();
      },
      scheduleTimer: (delay, callback) {
        final timer = ManualTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );
    final localClient = SignalingClient(
      webSocketClient: webSocketClient,
      deviceIdentitySession: localIdentity,
    );
    addTearDown(localClient.dispose);

    await localClient.connect(session: session);
    final retry = timers.single;
    await localClient.leave();
    retry.fire();
    await Future<void>.delayed(Duration.zero);

    expect(retry.isActive, isFalse);
    expect(localIdentity.forceRefreshes, [false]);
    expect(connectorCalls, 0);
  });

  test('a newer session supersedes an in-flight token operation', () async {
    final localIdentity = SupersededDeviceIdentitySession();
    final uris = <Uri>[];
    final webSocketClient = WebSocketClient(
      connector: (uri, headers) async {
        uris.add(uri);
        return FakeWebSocketConnection();
      },
      scheduleTimer: _instantTimer,
    );
    final localClient = SignalingClient(
      webSocketClient: webSocketClient,
      deviceIdentitySession: localIdentity,
    );
    addTearDown(localClient.dispose);
    final firstSession = StreamSession(
      sessionId: 'session-1',
      signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
    );
    final secondSession = StreamSession(
      sessionId: 'session-2',
      signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
    );

    final firstConnect = localClient.connect(session: firstSession);
    await localIdentity.firstStarted.future;
    await localClient.connect(session: secondSession);
    localIdentity.firstToken.complete('token-1');
    await firstConnect;

    expect(uris.map((uri) => uri.queryParameters), [
      {'sessionId': 'session-2'},
    ]);
  });

  test('does not auto-send viewer.ready on connect', () async {
    // `viewer.ready` is a routed message the backend rejects without a `to`
    // recipient. It is now sent by the WebRTC receiver in reply to
    // `publisher.ready`, not automatically on socket open.
    await signalingClient.connect(session: session);
    await Future<void>.delayed(Duration.zero);

    expect(connection.sent, isEmpty);
  });

  test('sends a targeted message via send()', () async {
    await signalingClient.connect(session: session);
    await Future<void>.delayed(Duration.zero);

    signalingClient.send(
      SignalingMessageType.viewerReady,
      const {},
      to: 'publisher-7',
    );

    expect(connection.sent, hasLength(1));
    final sentMessage = _decode(connection.sent.single);
    expect(sentMessage['type'], 'viewer.ready');
    expect(sentMessage['sessionId'], 'session-1');
    expect(sentMessage['to'], 'publisher-7');
  });

  test('replies with pong when the server sends a ping', () async {
    await signalingClient.connect(session: session);
    await Future<void>.delayed(Duration.zero);

    connection.emit(
      jsonEncode({
        'type': 'ping',
        'messageId': 'srv-1',
        'sessionId': 'session-1',
        'from': 'server',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'payload': {},
      }),
    );
    await Future<void>.delayed(Duration.zero);

    expect(connection.sent, hasLength(1));
    final pong = _decode(connection.sent.single);
    expect(pong['type'], 'pong');
    expect(pong['to'], 'server');
  });

  test('session.ended closes the connection and stops reconnecting', () async {
    await signalingClient.connect(session: session);
    await Future<void>.delayed(Duration.zero);

    final states = <SignalingConnectionState>[];
    final sub = signalingClient.connectionState.listen(states.add);

    connection.emit(
      jsonEncode({
        'type': 'session.ended',
        'messageId': 'srv-2',
        'sessionId': 'session-1',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'payload': {},
      }),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(states, contains(SignalingConnectionState.ended));
    expect(states.last, SignalingConnectionState.disconnected);
    expect(connection.closed, isTrue);

    await sub.cancel();
  });

  test('forwards unknown message types without throwing', () async {
    await signalingClient.connect(session: session);
    await Future<void>.delayed(Duration.zero);

    final messageFuture = signalingClient.messages.first;
    connection.emit(
      jsonEncode({
        'type': 'future.message',
        'messageId': 'srv-3',
        'sessionId': 'session-1',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'payload': {'x': 1},
      }),
    );

    final message = await messageFuture;
    expect(message.type, SignalingMessageType.unknown);
    expect(message.rawType, 'future.message');
  });
}
