import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists whether the viewer has completed (or skipped) the first-use
/// onboarding, so it is shown at most once per install. Absent (never set)
/// counts as not completed — a fresh install, or app data cleared, must see
/// onboarding again.
class OnboardingStorage {
  const OnboardingStorage(this._storage);

  static const _key = 'onboarding.completed';

  final FlutterSecureStorage _storage;

  Future<bool> read() async {
    final value = await _storage.read(key: _key);
    return value == 'true';
  }

  Future<void> write(bool value) =>
      _storage.write(key: _key, value: value ? 'true' : 'false');
}
