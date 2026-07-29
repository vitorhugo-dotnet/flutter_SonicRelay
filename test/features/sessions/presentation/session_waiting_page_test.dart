import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/features/devices/data/devices_repository.dart';
import 'package:sonic_relay/features/devices/domain/device.dart';
import 'package:sonic_relay/features/listener/presentation/listener_view_model.dart';
import 'package:sonic_relay/features/sessions/domain/stream_session.dart';
import 'package:sonic_relay/features/sessions/presentation/join_session_view_model.dart';
import 'package:sonic_relay/features/sessions/presentation/session_waiting_page.dart';

final _session = StreamSession(
  sessionId: 'session-1',
  signalingUrl: Uri.parse('wss://stream.example/ws/signaling'),
);

class _JoinedSessionViewModel extends JoinSessionViewModel {
  @override
  JoinSessionState build() => JoinSessionState(
    code: 'ABC123',
    status: JoinSessionStatus.joined,
    session: _session,
  );
}

class _ConnectedListenerViewModel extends ListenerViewModel {
  @override
  ListenerState build() => const ListenerState();

  @override
  Future<void> connect({required StreamSession session}) async {}
}

class _FailingLegacyDevicesRepository implements DevicesRepository {
  @override
  Future<String?> readCurrentDeviceId() =>
      Future<String?>.error(StateError('legacy device ID was read'));

  @override
  Future<Device> ensureCurrentDevice({required String platform}) =>
      throw UnimplementedError();

  @override
  Future<List<Device>> listDevices() => throw UnimplementedError();
}

void main() {
  testWidgets('opens listener without reading the legacy devices repository', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/waiting',
      routes: [
        GoRoute(
          path: '/waiting',
          builder: (_, _) => const SessionWaitingPage(),
        ),
        GoRoute(
          path: '/listener',
          builder: (_, _) => const Scaffold(body: Text('Listener connected')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          joinSessionViewModelProvider.overrideWith(
            _JoinedSessionViewModel.new,
          ),
          listenerViewModelProvider.overrideWith(
            _ConnectedListenerViewModel.new,
          ),
          devicesRepositoryProvider.overrideWithValue(
            _FailingLegacyDevicesRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Listener connected'), findsOneWidget);
  });
}
