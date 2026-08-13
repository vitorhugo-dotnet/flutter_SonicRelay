import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/storage/coturn_override_storage.dart';

void main() {
  const secureStorage = FlutterSecureStorage();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('defaults to null with nothing stored', () async {
    expect(await const CoturnOverrideStorage(secureStorage).read(), isNull);
  });

  test('round trips a written override', () async {
    const storage = CoturnOverrideStorage(secureStorage);

    await storage.write('turn:my-relay.example.com:3478');

    expect(await storage.read(), 'turn:my-relay.example.com:3478');
  });

  test('writing null clears a previously stored override', () async {
    const storage = CoturnOverrideStorage(secureStorage);
    await storage.write('turn:my-relay.example.com:3478');

    await storage.write(null);

    expect(await storage.read(), isNull);
  });

  test('writing an empty or blank string also clears the override', () async {
    const storage = CoturnOverrideStorage(secureStorage);
    await storage.write('turn:my-relay.example.com:3478');

    await storage.write('   ');

    expect(await storage.read(), isNull);
  });

  test('trims whitespace around a written override', () async {
    const storage = CoturnOverrideStorage(secureStorage);

    await storage.write('  turn:my-relay.example.com:3478  ');

    expect(await storage.read(), 'turn:my-relay.example.com:3478');
  });
}
