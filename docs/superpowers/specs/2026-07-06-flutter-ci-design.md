# Flutter CI Workflow Design

## Goal

Add GitHub Actions CI for the Flutter viewer so every push and pull request to
`main` is analyzed, tested, and built into an Android APK artifact — catching
broken assumptions early, before the project grows a museum of them.

## Constraints (from issue #9)

- Keep the workflow simple.
- Split work into separate jobs so a failure is easy to retry/debug.
- Use a maintained Flutter setup action.
- Cache dependencies where practical.
- Run `flutter pub get`, `flutter analyze`, and `flutter test`.
- Build an Android APK artifact.
- No signing keys, and no secrets unless strictly necessary.
- No app-store deploy in this issue.
- Trigger on push and pull_request to `main`.
- README documents how to run the same commands locally.

## Decisions

- **Single workflow file `.github/workflows/flutter-ci.yml` with three jobs:**
  `analyze`, `test`, and `build-android`. The jobs are independent (each does its
  own checkout + Flutter setup + `pub get`) so a red job can be retried in
  isolation, matching the issue's recommended split.
- **`subosito/flutter-action@v2` is the maintained setup action.** It is the
  de-facto standard for Flutter CI, supports built-in pub/SDK caching via
  `cache: true`, and pins an exact Flutter version.
- **Pin Flutter `3.38.1` / channel `stable`.** This is the version recorded in
  `.metadata` and used locally (Dart 3.10.0), so CI matches the developer
  environment and the `sdk: ^3.10.0` constraint in `pubspec.yaml`. A pinned
  version keeps CI reproducible instead of drifting with `stable`.
- **`build-android` builds a release APK (`flutter build apk --release`).** The
  Android `release` build type is configured to sign with the debug keys
  (`android/app/build.gradle.kts`), so a release build succeeds with **no signing
  keys and no secrets**, while still producing a representative artifact. The APK
  is uploaded via `actions/upload-artifact@v4`.
- **Java 17 via `actions/setup-java@v4` (Temurin) for the Android build.** The
  Gradle config targets `JavaVersion.VERSION_17`, so the build job provisions a
  matching JDK; `analyze` and `test` do not need it.
- **No job dependencies (`needs`).** All three run in parallel for fast feedback;
  none consumes another's output, so serializing them would only slow CI.

## Jobs and flow

```
push / pull_request → main
├─ analyze       checkout → setup-flutter(cache) → pub get → flutter analyze
├─ test          checkout → setup-flutter(cache) → pub get → flutter test
└─ build-android checkout → setup-java(17) → setup-flutter(cache) → pub get
                 → flutter build apk --release → upload-artifact(app-release.apk)
```

## Acceptance criteria

- Workflow triggers on push and pull_request to `main`.
- `analyze` job runs `flutter analyze`.
- `test` job runs `flutter test`.
- `build-android` job uploads an APK artifact.
- No signing keys or secrets are required.
- README documents running the same commands locally.
