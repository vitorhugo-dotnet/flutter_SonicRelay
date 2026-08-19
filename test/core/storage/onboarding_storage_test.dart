import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/storage/onboarding_storage.dart';

void main() {
  const secureStorage = FlutterSecureStorage();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('defaults to not completed with nothing stored', () async {
    expect(await const OnboardingStorage(secureStorage).read(), isFalse);
  });

  test('round trips a completed flag', () async {
    const storage = OnboardingStorage(secureStorage);

    await storage.write(true);

    expect(await storage.read(), isTrue);
  });

  test('writing false after true clears completion', () async {
    const storage = OnboardingStorage(secureStorage);
    await storage.write(true);

    await storage.write(false);

    expect(await storage.read(), isFalse);
  });
}
