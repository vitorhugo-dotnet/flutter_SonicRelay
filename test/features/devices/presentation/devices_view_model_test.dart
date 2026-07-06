import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/features/auth/presentation/login_view_model.dart';
import 'package:sonic_relay/features/devices/data/devices_repository.dart';
import 'package:sonic_relay/features/devices/domain/device.dart';
import 'package:sonic_relay/features/devices/domain/device_type.dart';
import 'package:sonic_relay/features/devices/presentation/devices_view_model.dart';

final currentDevice = Device(
  id: 'current-id',
  name: 'SonicRelay Android Viewer',
  type: DeviceType.flutterViewer,
  platform: 'android',
  publicKey: null,
  trusted: false,
  revoked: false,
  lastSeenAt: null,
  createdAt: DateTime.utc(2026, 7, 1),
);

class FakeDevicesRepository implements DevicesRepository {
  int registrations = 0;
  DevicesFailure? failure;

  @override
  Future<Device> ensureCurrentDevice({required String platform}) async {
    registrations++;
    if (failure case final value?) throw value;
    return currentDevice;
  }

  @override
  Future<List<Device>> listDevices() async => [currentDevice];

  @override
  Future<String?> readCurrentDeviceId() async => 'current-id';
}

class AuthenticatedAuthViewModel extends AuthViewModel {
  @override
  AuthState build() => const AuthState.authenticated();
}

void main() {
  test(
    'authenticated session automatically registers the current device',
    () async {
      final repository = FakeDevicesRepository();
      final container = ProviderContainer(
        overrides: [
          authViewModelProvider.overrideWith(AuthenticatedAuthViewModel.new),
          devicesRepositoryProvider.overrideWithValue(repository),
          devicePlatformProvider.overrideWithValue('android'),
        ],
      );
      addTearDown(container.dispose);

      container.read(devicesViewModelProvider);
      await Future<void>.delayed(Duration.zero);

      expect(repository.registrations, 1);
      expect(
        container.read(devicesViewModelProvider).currentDeviceId,
        'current-id',
      );
    },
  );

  test('registration failure is surfaced without throwing', () async {
    final repository = FakeDevicesRepository()
      ..failure = const DevicesFailure('Friendly registration error.');
    final container = ProviderContainer(
      overrides: [
        authViewModelProvider.overrideWith(AuthenticatedAuthViewModel.new),
        devicesRepositoryProvider.overrideWithValue(repository),
        devicePlatformProvider.overrideWithValue('android'),
      ],
    );
    addTearDown(container.dispose);

    container.read(devicesViewModelProvider);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(devicesViewModelProvider).errorMessage,
      'Friendly registration error.',
    );
    expect(container.read(authViewModelProvider).isAuthenticated, isTrue);
  });
}
