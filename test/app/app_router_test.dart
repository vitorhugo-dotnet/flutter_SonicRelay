import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/app/router/app_router.dart';

void main() {
  test('restoring identity stays on loading', () {
    expect(
      deviceIdentityRedirect(const DeviceReadinessState.restoring(), '/join'),
      '/loading',
    );
    expect(
      deviceIdentityRedirect(
        const DeviceReadinessState.restoring(),
        '/loading',
      ),
      isNull,
    );
  });

  test('missing or invalid credential goes to device setup', () {
    expect(
      deviceIdentityRedirect(const DeviceReadinessState.deviceSetup(), '/join'),
      '/device-setup',
    );
  });

  test('ready unpaired device goes to pairing', () {
    expect(
      deviceIdentityRedirect(
        const DeviceReadinessState.pairingRequired(),
        '/join',
      ),
      '/pair',
    );
  });

  test('paired device leaves onboarding for session join', () {
    expect(
      deviceIdentityRedirect(const DeviceReadinessState.ready(), '/loading'),
      '/join',
    );
    expect(
      deviceIdentityRedirect(const DeviceReadinessState.ready(), '/pair'),
      isNull,
    );
    expect(
      deviceIdentityRedirect(const DeviceReadinessState.ready(), '/settings'),
      isNull,
    );
  });

  test('production router exposes device-first routes without login', () {
    final container = ProviderContainer(
      overrides: [
        deviceReadinessProvider.overrideWith(_ReadyReadinessNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);
    final paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();

    expect(
      paths,
      containsAll(<String>{
        '/device-setup',
        '/pair',
        '/join',
        '/session/waiting',
        '/listener',
        '/settings',
      }),
    );
    expect(paths, isNot(contains('/login')));
  });

  test('unpaired device can still reach settings', () {
    expect(
      deviceIdentityRedirect(
        const DeviceReadinessState.pairingRequired(),
        '/settings',
      ),
      isNull,
    );
  });

  test('unpaired device is still redirected away from other pages', () {
    expect(
      deviceIdentityRedirect(
        const DeviceReadinessState.pairingRequired(),
        '/listener',
      ),
      '/pair',
    );
  });
}

class _ReadyReadinessNotifier extends DeviceReadinessNotifier {
  @override
  DeviceReadinessState build() => const DeviceReadinessState.ready();
}
