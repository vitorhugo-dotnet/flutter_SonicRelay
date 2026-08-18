import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the F-Droid requirement from SonicRelay#37: F-Droid builds every app
/// from source and rejects proprietary dependencies, so no package this app
/// resolves may pull a closed-source Google artifact into the Android build.
///
/// The regression this pins is `mobile_scanner`, which declared
/// `com.google.android.gms:play-services-mlkit-barcode-scanning` and
/// `com.google.mlkit:barcode-scanning` in its own `android/build.gradle`. A
/// Gradle product flavor cannot exclude it, because Flutter compiles and
/// registers every plugin regardless of the flavor being built.
const _proprietaryCoordinates = [
  'com.google.android.gms',
  'com.google.mlkit',
  'com.google.firebase',
  'com.google.ar',
];

/// Reads the resolved package -> disk location map pub writes at `pub get`.
Map<String, Directory> _resolvedPackages() {
  final config = File('.dart_tool/package_config.json');
  expect(
    config.existsSync(),
    isTrue,
    reason: 'Run `flutter pub get` before this test.',
  );

  final packages =
      (jsonDecode(config.readAsStringSync())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;

  return {
    for (final entry in packages.cast<Map<String, dynamic>>())
      entry['name'] as String: Directory.fromUri(
        config.absolute.uri.resolve(entry['rootUri'] as String),
      ),
  };
}

/// Every Gradle build script a resolved package contributes to the Android build.
Iterable<File> _gradleScriptsIn(Directory packageRoot) sync* {
  final android = Directory('${packageRoot.path}/android');
  if (!android.existsSync()) return;

  for (final entity in android.listSync(recursive: true)) {
    if (entity is File &&
        (entity.path.endsWith('.gradle') ||
            entity.path.endsWith('.gradle.kts'))) {
      yield entity;
    }
  }
}

void main() {
  test(
    'no resolved package declares a proprietary Google Android dependency',
    () {
      final offenders = <String>[];

      _resolvedPackages().forEach((name, root) {
        for (final script in _gradleScriptsIn(root)) {
          // `example/` ships a sample app that is never part of this build.
          if (script.path.contains('/example/')) continue;

          for (final coordinate in _proprietaryCoordinates) {
            if (script.readAsStringSync().contains(coordinate)) {
              offenders.add('$name -> $coordinate (${script.path})');
            }
          }
        }
      });

      expect(
        offenders,
        isEmpty,
        reason:
            'These packages would put closed-source Google artifacts in the APK, '
            'which blocks the F-Droid submission:\n${offenders.join('\n')}',
      );
    },
  );

  test('mobile_scanner is not resolved', () {
    expect(
      _resolvedPackages().keys,
      isNot(contains('mobile_scanner')),
      reason:
          'mobile_scanner pulls MLKit on Android; the pairing scanner must stay '
          'on a source-buildable ZXing implementation.',
    );
  });
}
