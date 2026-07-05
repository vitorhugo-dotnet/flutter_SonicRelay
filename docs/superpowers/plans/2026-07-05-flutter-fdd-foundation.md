# Flutter FDD Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a runnable Flutter viewer foundation that satisfies issue #1.

**Architecture:** Keep application-wide composition in `lib/app`, reusable technical adapters in `lib/core`, and user capabilities in feature-owned folders. Riverpod composes dependencies and go_router owns navigation.

**Tech Stack:** Flutter 3, Dart 3, Material 3, Riverpod, go_router, Dio, flutter_secure_storage, flutter_webrtc.

---

### Task 1: Generate and configure the project

**Files:**
- Create: Flutter platform scaffolding
- Modify: `pubspec.yaml`
- Modify: `analysis_options.yaml`

- [ ] Run `flutter create --project-name sonic_relay --org com.vitorhugo.sonicrelay .`.
- [ ] Add the five required runtime packages and `flutter_lints`.
- [ ] Run `flutter pub get`; expect exit code 0.

### Task 2: Write the boot and routing test (RED)

**Files:**
- Replace: `test/widget_test.dart`
- Create: `test/app/sonic_relay_app_test.dart`

- [ ] Pump `SonicRelayApp` inside `ProviderScope`.
- [ ] Assert that `Login` is visible and tapping `Join a session` opens `Join session`.
- [ ] Run `flutter test test/app/sonic_relay_app_test.dart`; expect failure because the application classes do not exist.

### Task 3: Implement the minimal application (GREEN)

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/app/sonic_relay_app.dart`
- Create: `lib/app/router/app_router.dart`
- Create: `lib/app/theme/app_theme.dart`
- Create: `lib/app/env/app_config.dart`
- Create: `lib/app/di/app_providers.dart`
- Create: `lib/core/http/http_client.dart`
- Create: `lib/core/storage/secure_storage.dart`
- Create: feature presentation pages under `lib/features`

- [ ] Add the root `ProviderScope` and `MaterialApp.router`.
- [ ] Implement `/`, `/join`, `/listener`, and `/settings` with feature-owned pages.
- [ ] Add `AppConfig` dart-define values and Riverpod providers for Dio and secure storage.
- [ ] Run the focused widget test; expect PASS.

### Task 4: Complete FDD skeleton and documentation

**Files:**
- Create: required empty FDD directories represented by `.gitkeep`
- Modify: `README.md`

- [ ] Reserve each issue-required feature and core boundary without adding behavior.
- [ ] Document architecture, related repositories, setup, dart-defines, and local commands.

### Task 5: Verify and publish

**Files:** All files in the implementation scope.

- [ ] Run `dart format lib test`; expect exit code 0.
- [ ] Run `flutter analyze`; expect no issues.
- [ ] Run `flutter test`; expect all tests pass.
- [ ] Review `git diff --check` and the scoped diff.
- [ ] Commit the scoped files on `main`, push `origin/main`, and close issue #1 with the commit reference.
