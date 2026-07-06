# Flutter CI Workflow — Implementation Plan

Spec: `docs/superpowers/specs/2026-07-06-flutter-ci-design.md`
Issue: #9

## Step 1 — Workflow file

- Create `.github/workflows/flutter-ci.yml`.
- `on: push` and `on: pull_request`, both filtered to `branches: [main]`.
- Shared: `runs-on: ubuntu-latest`, `actions/checkout@v4`,
  `subosito/flutter-action@v2` with `flutter-version: 3.38.1`, `channel: stable`,
  `cache: true`.
- `analyze` job: `flutter pub get` → `flutter analyze`.
- `test` job: `flutter pub get` → `flutter test`.
- `build-android` job: `actions/setup-java@v4` (Temurin 17) →
  Flutter setup → `flutter pub get` → `flutter build apk --release` →
  `actions/upload-artifact@v4` uploading `build/app/outputs/flutter-apk/app-release.apk`.

## Step 2 — README CI section

- Add a "Continuous integration" section describing the three jobs, the pinned
  Flutter version, and that no signing keys are needed.
- State the exact local commands that mirror CI (`flutter pub get`,
  `flutter analyze`, `flutter test`, `flutter build apk --release`).

## Step 3 — Verification

- Validate the workflow YAML parses.
- Run `flutter analyze` and `flutter test` locally to confirm CI will be green.
- Commit to `main`, push, close issue #9.
