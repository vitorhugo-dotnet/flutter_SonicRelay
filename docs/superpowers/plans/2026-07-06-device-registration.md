# Device Registration and Listing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register and persist the current Flutter viewer device after authentication and list user devices in Settings.

**Architecture:** A devices API serializes authenticated HTTP calls, a repository maps responses and coordinates secure device-ID persistence, and a Riverpod view model reacts to authenticated sessions. Settings consumes the view model and renders focused device cards.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, flutter_secure_storage, flutter_test

---

### Task 1: Device domain and transport models

**Files:**
- Create: `lib/features/devices/domain/device_type.dart`
- Create: `lib/features/devices/domain/device.dart`
- Create: `lib/features/devices/data/dto/register_device_request.dart`
- Create: `lib/features/devices/data/dto/device_response.dart`
- Create: `lib/features/devices/data/devices_api.dart`

- [ ] Define `DeviceType.flutterViewer`, the immutable `Device`, request JSON, response parsing, and authenticated POST/GET methods.
- [ ] Keep backend field names exact and parse ISO-8601 timestamps into `DateTime`.

### Task 2: Repository registration flow (TDD)

**Files:**
- Create: `lib/features/devices/data/device_id_storage.dart`
- Create: `lib/features/devices/data/devices_repository.dart`
- Create: `test/features/devices/data/devices_repository_test.dart`

- [ ] Write tests proving response mapping, first registration persistence, existing-ID reuse, and stale-ID replacement.
- [ ] Run `flutter test test/features/devices/data/devices_repository_test.dart` and confirm RED because device classes are missing.
- [ ] Implement the storage abstraction and minimal repository behavior.
- [ ] Run the same command and confirm GREEN.

### Task 3: Presentation state and application wiring (TDD)

**Files:**
- Modify: `lib/app/di/app_providers.dart`
- Create: `lib/features/devices/presentation/devices_view_model.dart`
- Create: `test/features/devices/presentation/devices_view_model_test.dart`

- [ ] Write tests for authenticated registration and friendly registration errors.
- [ ] Run the focused view-model test and confirm RED.
- [ ] Wire secure ID storage, API, repository, platform detection, and auth-triggered registration.
- [ ] Run the focused view-model test and confirm GREEN.

### Task 4: Device card and Settings list (TDD)

**Files:**
- Create: `lib/features/devices/presentation/widgets/device_card.dart`
- Modify: `lib/features/settings/presentation/settings_page.dart`
- Create: `test/features/devices/presentation/widgets/device_card_test.dart`

- [ ] Write the widget test for label, platform/type, current marker, and revoked/trusted status; confirm RED.
- [ ] Implement `DeviceCard` and the Settings loading/error/list states.
- [ ] Run the widget test and relevant app test; confirm GREEN.

### Task 5: Documentation and acceptance verification

**Files:**
- Modify: `README.md`

- [ ] Document registration timing, secure ID persistence, validation, and authenticated endpoints.
- [ ] Format changed Dart files with `dart format`.
- [ ] Run `flutter analyze` and require exit code 0.
- [ ] Run `flutter test` and require exit code 0, as explicitly required by issue #4.
- [ ] Review `git diff --check`, the spec, and this plan for full acceptance-criteria coverage.
- [ ] Commit on `main`, push `origin/main`, verify the remote commit, and close issue #4 with a completion comment.
