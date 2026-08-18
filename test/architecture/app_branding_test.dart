import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the naming rule from dotnet_SonicRelay#38: every surface a user can
/// read says exactly `SonicRelay`, while the technical identifiers that
/// publication and local persistence key off of stay untouched.
const _publicName = 'SonicRelay';

/// Files whose user-facing strings this test pins.
const _brandedFiles = [
  'android/app/src/main/AndroidManifest.xml',
  'ios/Runner/Info.plist',
];

/// The app ships to Android and iOS only; the web and desktop runners were
/// removed rather than left unmaintained (SonicRelay#37).
const _retiredPlatformDirs = ['web', 'linux', 'macos', 'windows'];

String _read(String path) => File(path).readAsStringSync();

/// Returns the value that follows [key] in an Apple property list.
String? _plistValue(String plist, String key) => RegExp(
  '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
).firstMatch(plist)?.group(1);

void main() {
  group('public app name is $_publicName', () {
    test('Android launcher label', () {
      expect(
        RegExp(r'android:label="([^"]*)"')
            .firstMatch(_read('android/app/src/main/AndroidManifest.xml'))
            ?.group(1),
        _publicName,
      );
    });

    test('iOS display name and bundle name', () {
      final plist = _read('ios/Runner/Info.plist');
      expect(_plistValue(plist, 'CFBundleDisplayName'), _publicName);
      expect(_plistValue(plist, 'CFBundleName'), _publicName);
    });

    test('in-app title', () {
      expect(_read('lib/app/sonic_relay_app.dart'), contains("title: '$_publicName'"));
    });

    test('no spaced or underscored variant reaches a user-facing surface', () {
      final forbidden = RegExp(r'Sonic[ _]Relay|sonic relay', caseSensitive: false);

      for (final path in _brandedFiles) {
        expect(
          _read(path),
          isNot(matches(forbidden)),
          reason: '$path still spells the product name with a space or underscore.',
        );
      }
    });
  });

  group('platform scope', () {
    test('only the Android and iOS runners are checked in', () {
      for (final dir in _retiredPlatformDirs) {
        expect(
          Directory(dir).existsSync(),
          isFalse,
          reason:
              '$dir/ is back in the tree. The app targets Android and iOS only, '
              'and the QR scanner (flutter_zxing) has no web implementation.',
        );
      }
    });
  });

  group('technical identifiers are left alone', () {
    test('Dart package name', () {
      expect(_read('pubspec.yaml'), contains('name: sonic_relay'));
    });

    test('Android application id', () {
      expect(
        _read('android/app/build.gradle.kts'),
        contains('com.vitorhugo.sonicrelay.sonic_relay'),
      );
    });
  });
}
