import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/webrtc/rtc_ice_server_config.dart';
import 'package:sonic_relay/core/webrtc/rtc_peer_connection_factory.dart';
import 'package:sonic_relay/core/websocket/websocket_client.dart';
import 'package:sonic_relay/features/device_identity/data/device_identity_session.dart';
import 'package:sonic_relay/features/listener/data/audio_receiver_service.dart';
import 'package:sonic_relay/features/listener/data/webrtc_receiver_service.dart';
import 'package:sonic_relay/features/listener/presentation/listener_view_model.dart';
import 'package:sonic_relay/features/sessions/domain/stream_session.dart';
import 'package:sonic_relay/features/signaling/data/signaling_client.dart';

class FakeAudioReceiverService implements AudioReceiverService {
  int stopCount = 0;

  @override
  bool get isPlaying => false;

  @override
  Future<void> play(RtcMediaStream stream) async {}

  @override
  Future<void> stop() async => stopCount++;
}

class FakeWebSocketConnection implements WebSocketConnection {
  final _controller = StreamController<dynamic>.broadcast();
  bool closed = false;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void add(String data) {}

  @override
  Future<void> close() async {
    closed = true;
    await _controller.close();
  }

  void emit(String data) => _controller.add(data);
}

class FakeDeviceIdentitySession implements DeviceIdentitySession {
  @override
  Future<String> accessToken({bool forceRefresh = false}) async => 'token-1';

  @override
  Future<void> reset() async {}
}

class PendingDeviceIdentitySession implements DeviceIdentitySession {
  final started = Completer<void>();
  final token = Completer<String>();

  @override
  Future<String> accessToken({bool forceRefresh = false}) {
    started.complete();
    return token.future;
  }

  @override
  Future<void> reset() async {}
}

class SlowAudioReceiverService implements AudioReceiverService {
  final stopStarted = Completer<void>();
  final stopResult = Completer<void>();

  @override
  bool get isPlaying => false;

  @override
  Future<void> play(RtcMediaStream stream) async {}

  @override
  Future<void> stop() {
    if (!stopStarted.isCompleted) stopStarted.complete();
    return stopResult.future;
  }
}

class CountingRtcPeerConnectionFactory implements RtcPeerConnectionFactory {
  var createCalls = 0;

  @override
  Future<RtcPeerConnection> create(RtcIceServerConfig iceServers) {
    createCalls++;
    throw StateError('peer connection must not be created after leave');
  }
}

void main() {
  test(
    'leave tears down the receiver and closes the signaling socket',
    () async {
      final audio = FakeAudioReceiverService();
      late FakeWebSocketConnection connection;
      final webSocketClient = WebSocketClient(
        connector: (uri, headers) async {
          connection = FakeWebSocketConnection();
          return connection;
        },
        scheduleTimer: (delay, callback) => Timer(Duration.zero, callback),
      );
      final signalingClient = SignalingClient(
        webSocketClient: webSocketClient,
        deviceIdentitySession: FakeDeviceIdentitySession(),
      );

      final container = ProviderContainer(
        overrides: [
          audioReceiverServiceProvider.overrideWithValue(audio),
          signalingClientProvider.overrideWithValue(signalingClient),
        ],
      );
      addTearDown(container.dispose);

      // Force the receiver + view model to build and subscribe.
      container.read(listenerViewModelProvider);

      await signalingClient.connect(
        session: StreamSession(
          sessionId: 'session-1',
          signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await container.read(listenerViewModelProvider.notifier).leave();

      expect(audio.stopCount, greaterThanOrEqualTo(1));
      expect(connection.closed, isTrue);
    },
  );

  test(
    'leave invalidates pending signaling before slow receiver teardown',
    () async {
      final identity = PendingDeviceIdentitySession();
      final audio = SlowAudioReceiverService();
      final peerFactory = CountingRtcPeerConnectionFactory();
      final receiver = WebRtcReceiverService(
        peerConnectionFactory: peerFactory,
        audioReceiver: audio,
      );
      var connectorCalls = 0;
      FakeWebSocketConnection? lateConnection;
      final webSocketClient = WebSocketClient(
        connector: (uri, headers) async {
          connectorCalls++;
          lateConnection = FakeWebSocketConnection();
          return lateConnection!;
        },
        scheduleTimer: (delay, callback) => Timer(Duration.zero, callback),
      );
      final signalingClient = SignalingClient(
        webSocketClient: webSocketClient,
        deviceIdentitySession: identity,
      );
      final container = ProviderContainer(
        overrides: [
          signalingClientProvider.overrideWithValue(signalingClient),
          webRtcReceiverServiceProvider.overrideWithValue(receiver),
        ],
      );
      addTearDown(() async {
        if (!audio.stopResult.isCompleted) audio.stopResult.complete();
        container.dispose();
        await signalingClient.dispose();
        await receiver.dispose();
      });
      final listener = container.read(listenerViewModelProvider.notifier);
      final connecting = listener.connect(
        session: StreamSession(
          sessionId: 'session-1',
          signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
        ),
      );
      await identity.started.future;

      final leaving = listener.leave();
      await audio.stopStarted.future;
      identity.token.complete('late-token');
      await connecting;
      await Future<void>.delayed(Duration.zero);
      final connection = lateConnection;
      if (connection != null && !connection.closed) {
        connection.emit(
          jsonEncode({
            'type': 'webrtc.offer',
            'messageId': 'late-offer',
            'sessionId': 'session-1',
            'from': 'publisher-1',
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'payload': {'sdp': 'late-sdp', 'type': 'offer'},
          }),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }
      final connectorCallsBeforeReceiverFinished = connectorCalls;
      final peerCreatesBeforeReceiverFinished = peerFactory.createCalls;

      audio.stopResult.complete();
      await leaving;

      expect(connectorCallsBeforeReceiverFinished, 0);
      expect(peerCreatesBeforeReceiverFinished, 0);
    },
  );

  test('leave closes a late connector before slow receiver teardown', () async {
    final audio = SlowAudioReceiverService();
    final peerFactory = CountingRtcPeerConnectionFactory();
    final receiver = WebRtcReceiverService(
      peerConnectionFactory: peerFactory,
      audioReceiver: audio,
    );
    final connectorStarted = Completer<void>();
    final connectorResult = Completer<WebSocketConnection>();
    final lateConnection = FakeWebSocketConnection();
    final webSocketClient = WebSocketClient(
      connector: (uri, headers) {
        connectorStarted.complete();
        return connectorResult.future;
      },
      scheduleTimer: (delay, callback) => Timer(Duration.zero, callback),
    );
    final signalingClient = SignalingClient(
      webSocketClient: webSocketClient,
      deviceIdentitySession: FakeDeviceIdentitySession(),
    );
    final container = ProviderContainer(
      overrides: [
        signalingClientProvider.overrideWithValue(signalingClient),
        webRtcReceiverServiceProvider.overrideWithValue(receiver),
      ],
    );
    addTearDown(() async {
      if (!audio.stopResult.isCompleted) audio.stopResult.complete();
      if (!connectorResult.isCompleted) {
        connectorResult.complete(lateConnection);
      }
      container.dispose();
      await signalingClient.dispose();
      await receiver.dispose();
    });
    final listener = container.read(listenerViewModelProvider.notifier);
    final connecting = listener.connect(
      session: StreamSession(
        sessionId: 'session-1',
        signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
      ),
    );
    await connectorStarted.future;

    final leaving = listener.leave();
    await audio.stopStarted.future;
    connectorResult.complete(lateConnection);
    await connecting;
    await Future<void>.delayed(Duration.zero);
    if (!lateConnection.closed) {
      lateConnection.emit(
        jsonEncode({
          'type': 'webrtc.offer',
          'messageId': 'late-offer',
          'sessionId': 'session-1',
          'from': 'publisher-1',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'payload': {'sdp': 'late-sdp', 'type': 'offer'},
        }),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }
    final socketClosedBeforeReceiverFinished = lateConnection.closed;
    final peerCreatesBeforeReceiverFinished = peerFactory.createCalls;

    audio.stopResult.complete();
    await leaving;

    expect(socketClosedBeforeReceiverFinished, isTrue);
    expect(peerCreatesBeforeReceiverFinished, 0);
  });
}
