import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/websocket/websocket_client.dart';

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

  void emitDone() => _controller.close();
}

class SlowCancelWebSocketConnection implements WebSocketConnection {
  final _stream = ControlledCancelStream();
  bool closed = false;

  Completer<void> get cancelStarted => _stream.subscription.cancelStarted;

  Completer<void> get cancelResult => _stream.subscription.cancelResult;

  @override
  Stream<dynamic> get stream => _stream;

  @override
  void add(String data) {}

  @override
  Future<void> close() async {
    closed = true;
  }
}

class ControlledCancelStream extends Stream<dynamic> {
  final subscription = ControlledCancelSubscription();

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => subscription;
}

class ControlledCancelSubscription implements StreamSubscription<dynamic> {
  final cancelStarted = Completer<void>();
  final cancelResult = Completer<void>();

  @override
  Future<void> cancel() {
    cancelStarted.complete();
    return cancelResult.future;
  }

  @override
  bool get isPaused => false;

  @override
  void onData(void Function(dynamic data)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue);
}

class SlowCloseWebSocketConnection implements WebSocketConnection {
  final _controller = StreamController<dynamic>.broadcast();
  final closeStarted = Completer<void>();
  final closeResult = Completer<void>();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void add(String data) {}

  @override
  Future<void> close() {
    closeStarted.complete();
    return closeResult.future;
  }
}

Timer _instantTimer(Duration delay, void Function() callback) =>
    Timer(Duration.zero, callback);

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

void main() {
  group('WebSocketClient', () {
    test('connects and emits connecting then connected', () async {
      final connections = <FakeWebSocketConnection>[];
      final client = WebSocketClient(
        connector: (uri, headers) async {
          final connection = FakeWebSocketConnection();
          connections.add(connection);
          return connection;
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);

      final states = <WebSocketConnectionState>[];
      final sub = client.connectionState.listen(states.add);

      await client.connect(Uri.parse('wss://example.test/ws'));
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        WebSocketConnectionState.connecting,
        WebSocketConnectionState.connected,
      ]);
      expect(connections, hasLength(1));
      await sub.cancel();
    });

    test('forwards decoded messages from the connection', () async {
      late FakeWebSocketConnection connection;
      final client = WebSocketClient(
        connector: (uri, headers) async {
          connection = FakeWebSocketConnection();
          return connection;
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);

      await client.connect(Uri.parse('wss://example.test/ws'));

      final messageFuture = client.messages.first;
      connection.emit('{"type":"ping","messageId":"1"}');
      final message = await messageFuture;

      expect(message.data['type'], 'ping');
    });

    test('send forwards raw text to the active connection', () async {
      late FakeWebSocketConnection connection;
      final client = WebSocketClient(
        connector: (uri, headers) async {
          connection = FakeWebSocketConnection();
          return connection;
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);

      await client.connect(Uri.parse('wss://example.test/ws'));
      client.send('hello');

      expect(connection.sent, ['hello']);
    });

    test('reconnects with backoff after the connection drops', () async {
      final connections = <FakeWebSocketConnection>[];
      final client = WebSocketClient(
        connector: (uri, headers) async {
          final connection = FakeWebSocketConnection();
          connections.add(connection);
          return connection;
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);

      final states = <WebSocketConnectionState>[];
      final sub = client.connectionState.listen(states.add);

      await client.connect(Uri.parse('wss://example.test/ws'));
      connections.single.emitDone();

      // Allow the disconnect handler, scheduled reconnect timer, and the
      // resulting connect attempt to run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(connections, hasLength(2));
      expect(states, [
        WebSocketConnectionState.connecting,
        WebSocketConnectionState.connected,
        WebSocketConnectionState.reconnecting,
        WebSocketConnectionState.connected,
      ]);
      await sub.cancel();
    });

    test('retries connector failures until it succeeds', () async {
      var attempts = 0;
      final connections = <FakeWebSocketConnection>[];
      final client = WebSocketClient(
        connector: (uri, headers) async {
          attempts++;
          if (attempts < 3) {
            throw Exception('connect failed');
          }
          final connection = FakeWebSocketConnection();
          connections.add(connection);
          return connection;
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);

      final connectedFuture = client.connectionState.firstWhere(
        (state) => state == WebSocketConnectionState.connected,
      );
      await client.connect(Uri.parse('wss://example.test/ws'));
      await connectedFuture;

      expect(attempts, 3);
      expect(connections, hasLength(1));
    });

    test('retries a transient headers failure before connecting', () async {
      var headerAttempts = 0;
      final requestedHeaders = <Map<String, String>>[];
      final timers = <ManualTimer>[];
      final client = WebSocketClient(
        connector: (uri, headers) async {
          requestedHeaders.add(headers);
          return FakeWebSocketConnection();
        },
        scheduleTimer: (delay, callback) {
          final timer = ManualTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      addTearDown(client.dispose);

      await client.connect(
        Uri.parse('wss://example.test/ws'),
        headersProvider: (isReconnect) async {
          headerAttempts++;
          if (headerAttempts == 1) throw Exception('token unavailable');
          return {'Authorization': 'DeviceBearer token-2'};
        },
      );

      expect(requestedHeaders, isEmpty);
      expect(timers.single.delay, const Duration(seconds: 1));

      timers.single.fire();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(headerAttempts, 2);
      expect(requestedHeaders.single['Authorization'], 'DeviceBearer token-2');
    });

    test('keeps increasing backoff across connector failures', () async {
      var connectorAttempts = 0;
      final timers = <ManualTimer>[];
      final client = WebSocketClient(
        connector: (uri, headers) async {
          connectorAttempts++;
          if (connectorAttempts < 3) throw Exception('connector unavailable');
          return FakeWebSocketConnection();
        },
        scheduleTimer: (delay, callback) {
          final timer = ManualTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      addTearDown(client.dispose);

      await client.connect(
        Uri.parse('wss://example.test/ws'),
        headersProvider: (_) async => {'Authorization': 'DeviceBearer token'},
      );
      expect(timers[0].delay, const Duration(seconds: 1));

      timers[0].fire();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(timers[1].delay, const Duration(seconds: 2));

      timers[1].fire();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(connectorAttempts, 3);
    });

    test('disconnect cancels a retry after headers failure', () async {
      var headerAttempts = 0;
      final timers = <ManualTimer>[];
      final client = WebSocketClient(
        connector: (uri, headers) async => FakeWebSocketConnection(),
        scheduleTimer: (delay, callback) {
          final timer = ManualTimer(delay, callback);
          timers.add(timer);
          return timer;
        },
      );
      addTearDown(client.dispose);

      await client.connect(
        Uri.parse('wss://example.test/ws'),
        headersProvider: (_) async {
          headerAttempts++;
          throw Exception('token unavailable');
        },
      );
      final timer = timers.single;

      await client.disconnect();
      timer.fire();
      await Future<void>.delayed(Duration.zero);

      expect(timer.isActive, isFalse);
      expect(headerAttempts, 1);
    });

    test('disconnect invalidates an in-flight headers operation', () async {
      final headersStarted = Completer<void>();
      final headersResult = Completer<Map<String, String>>();
      var connectorCalls = 0;
      final client = WebSocketClient(
        connector: (uri, headers) async {
          connectorCalls++;
          return FakeWebSocketConnection();
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);

      final connecting = client.connect(
        Uri.parse('wss://example.test/ws'),
        headersProvider: (_) {
          headersStarted.complete();
          return headersResult.future;
        },
      );
      await headersStarted.future;

      await client.disconnect();
      headersResult.complete({'Authorization': 'DeviceBearer late-token'});
      await connecting;

      expect(connectorCalls, 0);
    });

    test('superseded connect still closes its captured connection', () async {
      final firstConnection = SlowCancelWebSocketConnection();
      final uris = <Uri>[];
      final client = WebSocketClient(
        connector: (uri, headers) async {
          uris.add(uri);
          if (uris.length == 1) return firstConnection;
          return FakeWebSocketConnection();
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);
      await client.connect(Uri.parse('wss://example.test/one'));

      final secondConnect = client.connect(Uri.parse('wss://example.test/two'));
      await firstConnection.cancelStarted.future;
      await client.connect(Uri.parse('wss://example.test/three'));
      firstConnection.cancelResult.complete();
      await secondConnect;

      expect(firstConnection.closed, isTrue);
      expect(uris.map((uri) => uri.path), ['/one', '/three']);
    });

    test('superseded disconnect does not overwrite connected state', () async {
      final firstConnection = SlowCloseWebSocketConnection();
      var connectorCalls = 0;
      final client = WebSocketClient(
        connector: (uri, headers) async {
          connectorCalls++;
          if (connectorCalls == 1) return firstConnection;
          return FakeWebSocketConnection();
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);
      final states = <WebSocketConnectionState>[];
      final subscription = client.connectionState.listen(states.add);
      addTearDown(subscription.cancel);
      await client.connect(Uri.parse('wss://example.test/one'));

      final disconnecting = client.disconnect();
      await firstConnection.closeStarted.future;
      await client.connect(Uri.parse('wss://example.test/two'));
      firstConnection.closeResult.complete();
      await disconnecting;
      await Future<void>.delayed(Duration.zero);

      expect(states.last, WebSocketConnectionState.connected);
    });

    test('disconnect stops reconnect attempts', () async {
      final connections = <FakeWebSocketConnection>[];
      final client = WebSocketClient(
        connector: (uri, headers) async {
          final connection = FakeWebSocketConnection();
          connections.add(connection);
          return connection;
        },
        scheduleTimer: _instantTimer,
      );
      addTearDown(client.dispose);

      await client.connect(Uri.parse('wss://example.test/ws'));
      await client.disconnect();

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(connections, hasLength(1));
    });
  });
}
