import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/storage/relay_mode_storage.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';

void main() {
  const secureStorage = FlutterSecureStorage();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('defaults to automatic with nothing stored', () async {
    expect(await const RelayModeStorage(secureStorage).read(), RelayModes.automatic);
  });

  test('round trips a written relay mode', () async {
    const storage = RelayModeStorage(secureStorage);

    await storage.write(RelayModes.disableFallback);

    expect(await storage.read(), RelayModes.disableFallback);
  });

  test('migrates a legacy forceRelay=true flag to the forceRelay mode', () async {
    await secureStorage.write(key: 'webrtc.forceRelay', value: 'true');

    expect(await const RelayModeStorage(secureStorage).read(), RelayModes.forceRelay);
  });

  test('migrates a legacy forceRelay=false flag to automatic', () async {
    await secureStorage.write(key: 'webrtc.forceRelay', value: 'false');

    expect(await const RelayModeStorage(secureStorage).read(), RelayModes.automatic);
  });
}
