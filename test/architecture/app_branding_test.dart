import 'dart:convert';
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
  'macos/Runner/Configs/AppInfo.xcconfig',
  'linux/runner/my_application.cc',
  'windows/runner/main.cpp',
  'windows/runner/Runner.rc',
  'web/index.html',
  'web/manifest.json',
];

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

    test('macOS product name', () {
      expect(
        RegExp(r'^PRODUCT_NAME\s*=\s*(.+)$', multiLine: true)
            .firstMatch(_read('macos/Runner/Configs/AppInfo.xcconfig'))
            ?.group(1)
            .toString()
            .trim(),
        _publicName,
      );
    });

    test('Linux window and header bar titles', () {
      final source = _read('linux/runner/my_application.cc');
      final titles = RegExp(r'gtk_(?:window|header_bar)_set_title\([^,]+,\s*"([^"]*)"')
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(titles, isNotEmpty, reason: 'No GTK title call found to check.');
      expect(titles, everyElement(_publicName));
    });

    test('Windows window title', () {
      expect(
        RegExp(r'window\.Create\(L"([^"]*)"')
            .firstMatch(_read('windows/runner/main.cpp'))
            ?.group(1),
        _publicName,
      );
    });

    test('Windows executable product metadata', () {
      final resources = _read('windows/runner/Runner.rc');
      for (final field in ['ProductName', 'FileDescription']) {
        expect(
          RegExp('VALUE "$field", "([^"]*)"')
              .firstMatch(resources)
              ?.group(1),
          _publicName,
          reason: '$field in Runner.rc should read $_publicName.',
        );
      }
    });

    test('web page and PWA titles', () {
      final html = _read('web/index.html');
      expect(
        RegExp(r'<title>([^<]*)</title>').firstMatch(html)?.group(1),
        _publicName,
      );
      expect(
        RegExp(r'name="apple-mobile-web-app-title"\s+content="([^"]*)"')
            .firstMatch(html)
            ?.group(1),
        _publicName,
      );

      final manifest =
          jsonDecode(_read('web/manifest.json')) as Map<String, dynamic>;
      expect(manifest['name'], _publicName);
      expect(manifest['short_name'], _publicName);
    });

    test('in-app title', () {
      expect(_read('lib/app/sonic_relay_app.dart'), contains("title: '$_publicName'"));
    });

    test('no spaced or underscored variant reaches a user-facing surface', () {
      final forbidden = RegExp(r'Sonic[ _]Relay|sonic relay', caseSensitive: false);

      // Runner.rc is excluded: it deliberately mixes the display name with the
      // `sonic_relay.exe` filename, so the exact-field assertions above cover
      // it instead of a whole-file scan.
      for (final path in _brandedFiles.where((p) => !p.endsWith('Runner.rc'))) {
        expect(
          _read(path),
          isNot(matches(forbidden)),
          reason: '$path still spells the product name with a space or underscore.',
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

    test('Linux application id and binary name', () {
      final cmake = _read('linux/CMakeLists.txt');
      expect(cmake, contains('set(BINARY_NAME "sonic_relay")'));
      expect(
        cmake,
        contains('set(APPLICATION_ID "com.vitorhugo.sonicrelay.sonic_relay")'),
      );
    });

    test('Windows binary name', () {
      expect(
        _read('windows/CMakeLists.txt'),
        contains('set(BINARY_NAME "sonic_relay")'),
      );
      expect(
        _read('windows/runner/Runner.rc'),
        contains('VALUE "OriginalFilename", "sonic_relay.exe"'),
      );
    });

    test('macOS bundle identifier', () {
      expect(
        _read('macos/Runner/Configs/AppInfo.xcconfig'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.vitorhugo.sonicrelay.sonicRelay'),
      );
    });
  });
}
