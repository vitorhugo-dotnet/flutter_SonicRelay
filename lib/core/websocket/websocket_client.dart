import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../diagnostics/diagnostic_log.dart';
import 'websocket_message.dart';

enum WebSocketConnectionState {
  connecting,
  connected,
  reconnecting,
  disconnected,
}

enum WebSocketDisconnectReason { normal, serverClosed, transportError, connectFailed }

/// A single open transport connection, abstracted so [WebSocketClient] can
/// be tested without opening a real socket.
abstract interface class WebSocketConnection {
  Stream<dynamic> get stream;

  void add(String data);

  Future<void> close();
}

typedef WebSocketConnector =
    Future<WebSocketConnection> Function(Uri uri, Map<String, String> headers);

/// Produces connection headers (e.g. a bearer token) fresh for each connect
/// attempt, so a token that expires mid-outage is picked up on the next
/// retry instead of retrying forever with a stale, now-rejected header.
/// [isReconnect] is true for every attempt after the first, so a provider
/// can force a token refresh only when retrying.
typedef WebSocketHeadersProvider =
    Future<Map<String, String>> Function(bool isReconnect);

/// Decides whether a connect failure should be retried. Returning false
/// stops all further reconnect attempts (e.g. when the device identity has
/// been revoked and retrying would never succeed).
typedef WebSocketReconnectPredicate = bool Function(Object error);

/// Default [WebSocketConnector] backed by `dart:io`'s [WebSocket].
Future<WebSocketConnection> ioWebSocketConnector(
  Uri uri,
  Map<String, String> headers,
) async {
  final socket = await WebSocket.connect(uri.toString(), headers: headers);
  return _IoWebSocketConnection(socket);
}

class _IoWebSocketConnection implements WebSocketConnection {
  _IoWebSocketConnection(this._socket);

  final WebSocket _socket;

  @override
  Stream<dynamic> get stream => _socket;

  @override
  void add(String data) => _socket.add(data);

  @override
  Future<void> close() => _socket.close();
}

/// Exponential backoff with a cap, used between reconnect attempts.
class ReconnectPolicy {
  const ReconnectPolicy({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.jitterRatio = 0.2,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;

  /// Fraction of the computed delay randomized in both directions (e.g. 0.2
  /// means +/-20%), so clients dropped by the same outage don't all retry the
  /// API in lockstep. Zero disables jitter.
  final double jitterRatio;

  Duration delayForAttempt(int attempt) {
    final scaledMillis =
        initialDelay.inMilliseconds * math.pow(multiplier, attempt);
    final cappedMillis = scaledMillis.clamp(
      initialDelay.inMilliseconds.toDouble(),
      maxDelay.inMilliseconds.toDouble(),
    );
    return Duration(milliseconds: cappedMillis.round());
  }

  /// [delayForAttempt] jittered by +/-[jitterRatio], using [jitterSample] — a
  /// value in [-1, 1] — as the random draw. Clamped to [0, maxDelay].
  Duration jitteredDelayForAttempt(int attempt, double jitterSample) {
    final base = delayForAttempt(attempt);
    final ratio = jitterRatio.clamp(0.0, 1.0);
    if (ratio <= 0) return base;
    final fraction = ratio * jitterSample.clamp(-1.0, 1.0);
    final jitteredMillis = (base.inMilliseconds * (1 + fraction)).clamp(
      0.0,
      maxDelay.inMilliseconds.toDouble(),
    );
    return Duration(milliseconds: jitteredMillis.round());
  }
}

/// Reconnecting JSON-over-WebSocket transport.
///
/// This class carries no domain knowledge of the messages it ferries; see
/// `features/signaling` for message semantics and routing.
class WebSocketClient {
  WebSocketClient({
    required WebSocketConnector connector,
    required DiagnosticLog diagnosticLog,
    ReconnectPolicy reconnectPolicy = const ReconnectPolicy(),
    Timer Function(Duration delay, void Function() callback)? scheduleTimer,
    math.Random? random,
  }) : _connector = connector,
       _diagnosticLog = diagnosticLog,
       _reconnectPolicy = reconnectPolicy,
       _scheduleTimer = scheduleTimer ?? Timer.new,
       _random = random ?? math.Random();

  final WebSocketConnector _connector;
  final DiagnosticLog _diagnosticLog;
  final ReconnectPolicy _reconnectPolicy;
  final Timer Function(Duration delay, void Function() callback)
  _scheduleTimer;
  final math.Random _random;

  final _stateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final _messageController = StreamController<WebSocketMessage>.broadcast();
  final _disconnectReasonController =
      StreamController<WebSocketDisconnectReason>.broadcast();

  Stream<WebSocketConnectionState> get connectionState =>
      _stateController.stream;

  Stream<WebSocketMessage> get messages => _messageController.stream;

  Stream<WebSocketDisconnectReason> get disconnectReasons =>
      _disconnectReasonController.stream;

  WebSocketConnection? _connection;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _attempt = 0;
  int _generation = 0;
  bool _stopped = true;
  Uri? _uri;
  Map<String, String> _headers = const {};
  WebSocketHeadersProvider? _headersProvider;
  WebSocketReconnectPredicate _shouldReconnectOnError = (_) => true;

  Future<void> connect(
    Uri uri, {
    Map<String, String> headers = const {},
    WebSocketHeadersProvider? headersProvider,
    WebSocketReconnectPredicate? shouldReconnectOnError,
  }) async {
    final generation = ++_generation;
    _stopped = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final previousSubscription = _subscription;
    _subscription = null;
    final previousConnection = _connection;
    _connection = null;
    if (previousSubscription != null) {
      await previousSubscription.cancel();
      if (!_isCurrent(generation) && previousConnection == null) return;
    }
    if (previousConnection != null) {
      await previousConnection.close();
    }
    if (!_isCurrent(generation)) return;

    _uri = uri;
    _headers = headers;
    _headersProvider = headersProvider;
    _shouldReconnectOnError = shouldReconnectOnError ?? (_) => true;
    _attempt = 0;
    await _attemptConnect(generation);
  }

  Future<void> _attemptConnect(int generation) async {
    if (!_isCurrent(generation)) return;
    if (_attempt == 0) {
      _stateController.add(WebSocketConnectionState.connecting);
    }
    try {
      final uri = _uri!;
      final isReconnect = _attempt > 0;
      unawaited(
        _diagnosticLog.write(
          'WebSocket',
          'connecting to $uri (attempt $_attempt)',
        ),
      );
      final headersProvider = _headersProvider;
      final headers = headersProvider == null
          ? _headers
          : await headersProvider(isReconnect);
      if (!_isCurrent(generation)) return;
      final connection = await _connector(uri, headers);
      if (!_isCurrent(generation)) {
        await connection.close();
        return;
      }
      _connection = connection;
      _attempt = 0;
      unawaited(_diagnosticLog.write('WebSocket', 'connected to $uri'));
      _stateController.add(WebSocketConnectionState.connected);
      _subscription = connection.stream.listen(
        (dynamic data) {
          if (_isCurrent(generation) && data is String) {
            _messageController.add(WebSocketMessage.decode(data));
          }
        },
        onDone: () {
          unawaited(
            _diagnosticLog.write('WebSocket', 'socket closed by peer'),
          );
          _disconnectReasonController.add(
            WebSocketDisconnectReason.serverClosed,
          );
          _handleDisconnect(generation, connection);
        },
        onError: (Object error) {
          unawaited(_diagnosticLog.write('WebSocket', 'socket error'));
          _disconnectReasonController.add(
            WebSocketDisconnectReason.transportError,
          );
          _handleDisconnect(generation, connection);
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      unawaited(_diagnosticLog.write('WebSocket', 'connect failed'));
      _disconnectReasonController.add(WebSocketDisconnectReason.connectFailed);
      if (!_shouldReconnectOnError(error)) {
        _stopped = true;
        _stateController.add(WebSocketConnectionState.disconnected);
        return;
      }
      _scheduleReconnect(generation);
    }
  }

  void _handleDisconnect(int generation, WebSocketConnection connection) {
    if (!_isCurrent(generation) || !identical(_connection, connection)) return;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _connection = null;
    _scheduleReconnect(generation);
  }

  void _scheduleReconnect(int generation) {
    if (!_isCurrent(generation)) return;
    final jitterSample = _random.nextDouble() * 2 - 1;
    final delay = _reconnectPolicy.jitteredDelayForAttempt(
      _attempt,
      jitterSample,
    );
    _attempt++;
    _stateController.add(WebSocketConnectionState.reconnecting);
    _reconnectTimer = _scheduleTimer(delay, () {
      if (_isCurrent(generation)) {
        unawaited(_attemptConnect(generation));
      }
    });
  }

  bool _isCurrent(int generation) => !_stopped && generation == _generation;

  /// Sends a raw text frame. Silently dropped while disconnected.
  void send(String data) => _connection?.add(data);

  /// Closes the connection and stops all reconnect attempts.
  Future<void> disconnect() async {
    final generation = ++_generation;
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final subscription = _subscription;
    _subscription = null;
    final connection = _connection;
    _connection = null;
    await subscription?.cancel();
    final supersededAfterCancel = generation != _generation || !_stopped;
    await connection?.close();
    if (supersededAfterCancel || generation != _generation || !_stopped) {
      return;
    }
    _disconnectReasonController.add(WebSocketDisconnectReason.normal);
    _stateController.add(WebSocketConnectionState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _messageController.close();
    await _disconnectReasonController.close();
  }
}
