# Session Join Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement authenticated temporary-code session joining for a registered Flutter viewer.

**Architecture:** Session DTO/API/repository code owns transport and in-memory context. A Riverpod ViewModel owns normalization, validation, async state, and auth-expiry behavior; presentation widgets render that state and route to a waiting screen.

**Tech Stack:** Dart, Flutter Material 3, Riverpod, Dio, go_router, flutter_test

---

### Task 1: Domain, DTO, API, and repository

**Files:**
- Create: `lib/features/sessions/domain/session_status.dart`
- Create: `lib/features/sessions/domain/stream_session.dart`
- Create: `lib/features/sessions/data/dto/join_session_request.dart`
- Create: `lib/features/sessions/data/dto/join_session_response.dart`
- Create: `lib/features/sessions/data/sessions_api.dart`
- Create: `lib/features/sessions/data/sessions_repository.dart`
- Create: `test/features/sessions/data/sessions_repository_test.dart`

- [ ] Write repository tests whose fake API captures `JoinSessionRequest(code: 'ABC123', deviceId: 'viewer-device')`, returns a response, and throws Dio errors for invalid, expired, and max-viewer cases.
- [ ] Run `flutter test test/features/sessions/data/sessions_repository_test.dart`; expect failure because the session types do not exist.
- [ ] Implement immutable DTO/domain types, `DioSessionsApi.join()` posting to `/api/sessions/join`, and `SessionsRepository.join()` that validates a stored device ID, maps failures, and stores `currentSession` in memory.
- [ ] Re-run the targeted repository test; expect all cases to pass.

### Task 2: ViewModel behavior

**Files:**
- Create: `lib/features/sessions/presentation/join_session_view_model.dart`
- Modify: `lib/app/di/app_providers.dart`
- Create: `test/features/sessions/presentation/join_session_view_model_test.dart`

- [ ] Write tests proving ` sr-4f8k ` becomes `SR-4F8K`, empty/malformed input never reaches the repository, success exposes a `StreamSession`, known failures expose friendly messages, and unauthorized failures expire auth.
- [ ] Run `flutter test test/features/sessions/presentation/join_session_view_model_test.dart`; expect failure because the provider/ViewModel do not exist.
- [ ] Add API/repository providers and implement `JoinSessionState` plus `JoinSessionViewModel` with `updateCode`, `join`, and `retry` methods.
- [ ] Re-run the targeted ViewModel test; expect all cases to pass.

### Task 3: Session UI and navigation

**Files:**
- Modify: `lib/features/sessions/presentation/join_session_page.dart`
- Create: `lib/features/sessions/presentation/session_waiting_page.dart`
- Create: `lib/features/sessions/presentation/widgets/session_code_input.dart`
- Create: `lib/features/sessions/presentation/widgets/session_status_card.dart`
- Modify: `lib/app/router/app_router.dart`
- Create: `test/features/sessions/presentation/widgets/session_code_input_test.dart`
- Create: `test/features/sessions/presentation/join_session_page_test.dart`

- [ ] Write widget tests proving the code field displays normalized uppercase input and validation text, and the page delegates submit behavior to the ViewModel.
- [ ] Run both targeted widget test files; expect failure because the widgets/page behavior do not exist.
- [ ] Implement the controlled input, status card, Consumer join page, waiting page, and `/session/waiting` route. Use a provider listener to navigate exactly once after success.
- [ ] Re-run both targeted widget test files; expect all cases to pass.

### Task 4: Documentation and verification

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-07-06-session-join.md`

- [ ] Document the join endpoint, request/response contract, registered-device prerequisite, in-memory context, and waiting route in README.
- [ ] Run `dart format` only on changed Dart files.
- [ ] Run `flutter test test/features/sessions`; expect zero failures.
- [ ] Run `flutter analyze`; expect exit code 0.
- [ ] Run `flutter test`; expect exit code 0 because the issue explicitly requires the full suite.
- [ ] Mark this plan's checkboxes complete, inspect `git diff --check`, and review the scoped diff against issue #5.
- [ ] Commit the scoped files on `main` with `feat: implement session join flow`, push `main`, close issue #5 with the commit reference, and confirm the remote issue state is `CLOSED`.
