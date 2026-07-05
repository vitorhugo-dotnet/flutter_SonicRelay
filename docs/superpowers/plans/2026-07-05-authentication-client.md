# Authentication Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement secure token authentication, refresh, startup restoration, logout, and protected navigation for the Flutter viewer.

**Architecture:** A feature-owned repository coordinates an API abstraction and secure token storage. Riverpod owns application auth state, while a Dio interceptor handles bearer injection and one-time refresh/retry; go_router redirects from that state.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, flutter_secure_storage, go_router, flutter_test

---

### Task 1: Domain, DTO, and storage contracts

**Files:** Create `lib/features/auth/domain/auth_session.dart`, `lib/features/auth/domain/auth_user.dart`, auth DTO files, `lib/core/storage/secure_token_storage.dart`, and `test/core/storage/secure_token_storage_test.dart`.

- [x] Write a fake-storage contract test proving token pairs round-trip and clear.
- [x] Run `flutter test test/core/storage/secure_token_storage_test.dart` and confirm it fails because the contract is absent.
- [x] Implement immutable auth values, JSON DTO parsing, `TokenStorage`, and the flutter_secure_storage adapter.
- [x] Re-run the targeted storage test and confirm it passes.

### Task 2: API and repository flows

**Files:** Create `lib/features/auth/data/auth_api.dart`, `lib/features/auth/data/auth_repository.dart`, and `test/features/auth/data/auth_repository_test.dart`.

- [x] Write fake-API tests for login persistence, refresh replacement, restoration, and logout clearing after an API error.
- [x] Run the repository test and confirm failure because repository behavior is absent.
- [x] Implement the Dio API adapter and repository with friendly typed auth failures.
- [x] Re-run repository tests and confirm they pass.

### Task 3: HTTP refresh integration and providers

**Files:** Create `lib/core/http/dio_client.dart`, `lib/core/http/auth_interceptor.dart`; modify `lib/app/di/app_providers.dart`.

- [x] Add focused interceptor tests for bearer injection, refresh/retry, and refresh failure cleanup.
- [x] Run the focused interceptor tests and confirm refresh/retry and failure cleanup behavior.
- [x] Implement the shared Dio client, interceptor, and dependency graph without logging credentials.
- [x] Re-run focused tests and confirm they pass.

### Task 4: Auth state, login, and route guards

**Files:** Create `lib/features/auth/presentation/login_view_model.dart`; modify `lib/features/auth/presentation/login_page.dart`, `lib/app/router/app_router.dart`, `lib/app/sonic_relay_app.dart`, and app/widget tests.

- [x] Write widget tests for empty/invalid input and router tests proving `/join` is protected.
- [x] Run only those widget/router tests and confirm they fail on current presentation-only behavior.
- [x] Connect form controllers and validation to `AuthViewModel`, expose progress/errors, add logout, and make the router reactive.
- [x] Re-run those tests and confirm they pass.

### Task 5: Documentation and final verification

**Files:** Modify `README.md` and remove superseded `lib/core/http/http_client.dart` and `lib/core/storage/secure_storage.dart`.

- [x] Document backend endpoints, dart-define configuration, secure token behavior, and guarded routes.
- [x] Run `dart format lib test`, `flutter analyze`, and `flutter test`; resolve only issues introduced by this work.
- [x] Inspect `git diff --check` and the scoped diff, commit to `main`, push `origin/main`, and close issue #3 with the commit reference.
