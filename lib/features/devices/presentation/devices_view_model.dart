import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../auth/presentation/login_view_model.dart';
import '../data/devices_repository.dart';
import '../domain/device.dart';

class DevicesState {
  const DevicesState({
    this.devices = const [],
    this.currentDeviceId,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Device> devices;
  final String? currentDeviceId;
  final bool isLoading;
  final String? errorMessage;
}

final devicesViewModelProvider =
    NotifierProvider<DevicesViewModel, DevicesState>(DevicesViewModel.new);

class DevicesViewModel extends Notifier<DevicesState> {
  late final DevicesRepository _repository;
  late final String _platform;

  @override
  DevicesState build() {
    _repository = ref.watch(devicesRepositoryProvider);
    _platform = ref.watch(devicePlatformProvider);
    ref.listen(authViewModelProvider, (previous, next) {
      final becameAuthenticated =
          next.isAuthenticated && previous?.isAuthenticated != true;
      if (becameAuthenticated) Future<void>.microtask(refresh);
    }, fireImmediately: true);
    return const DevicesState();
  }

  Future<void> refresh() async {
    state = DevicesState(
      devices: state.devices,
      currentDeviceId: state.currentDeviceId,
      isLoading: true,
    );
    try {
      final current = await _repository.ensureCurrentDevice(
        platform: _platform,
      );
      final devices = await _repository.listDevices();
      state = DevicesState(devices: devices, currentDeviceId: current.id);
    } on DevicesFailure catch (error) {
      state = DevicesState(
        devices: state.devices,
        currentDeviceId: await _repository.readCurrentDeviceId(),
        errorMessage: error.message,
      );
    } catch (_) {
      state = DevicesState(
        devices: state.devices,
        currentDeviceId: state.currentDeviceId,
        errorMessage: 'Unable to prepare this device. Please retry.',
      );
    }
  }
}
