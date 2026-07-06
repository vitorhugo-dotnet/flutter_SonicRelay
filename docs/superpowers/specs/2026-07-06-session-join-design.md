# Session Join Design

## Goal

Allow an authenticated Flutter viewer with a registered device to join a temporary SonicRelay session code and retain the returned signaling context in memory.

## Decisions

- Keep all session behavior under `lib/features/sessions` and compose dependencies in `app_providers.dart`.
- Normalize codes with `trim().toUpperCase()` and accept only 4-12 ASCII letters, digits, or hyphens. Validation runs before any API call.
- `SessionsRepository` reads the registered device ID, calls `POST /api/sessions/join` through the authenticated Dio client, maps the DTO to `StreamSession`, and retains the current session in memory.
- Repository failures have explicit kinds: missing device, invalid/expired code, maximum viewers, unauthorized, network, and invalid server response. Known backend error text is also inspected so compatible status-code variations still produce friendly messages.
- `JoinSessionViewModel` owns input normalization, validation, loading, retryable state, current session state, and session-expired redirect signaling. Widgets contain no join rules.
- A successful join navigates to `/session/waiting`. The waiting page reads the in-memory context and displays a connecting state plus the prepared signaling URL host/context. The existing listener route remains unchanged for the later signaling issue.
- Unauthorized responses expire the authentication ViewModel, allowing the existing router guard to redirect to `/login`.

## Components and data flow

1. `SessionCodeInput` sends raw text to `JoinSessionViewModel.updateCode`.
2. The ViewModel stores normalized text and validates it locally.
3. On submit, `SessionsRepository.join` obtains `DevicesRepository.readCurrentDeviceId()` and refuses to call HTTP when absent.
4. `DioSessionsApi` serializes `JoinSessionRequest` and parses `JoinSessionResponse`.
5. The repository maps the response to `StreamSession`, stores it in memory, and returns it.
6. The ViewModel exposes success; `JoinSessionPage` navigates to the waiting route.

## UI states

- Idle: editable code and enabled Join button.
- Invalid: field-level friendly validation without HTTP.
- Joining: disabled input/button with progress.
- Failed: status card with friendly message and retry action for network/server failures.
- Joined: navigation to a waiting page showing session ID, viewer role, and connecting status.

## Tests

- Unit: code normalization and local validation.
- Unit: repository request shape, successful in-memory context, and invalid/expired/max-viewers mappings.
- Unit: ViewModel success, missing-device, failure, and unauthorized behavior.
- Widget: code input capitalization/display and validation rendering.
- Targeted router test: waiting route remains protected by the existing auth redirect.

## Acceptance criteria

- All issue #5 requirements are represented in code and README documentation.
- `flutter analyze` exits successfully.
- Relevant session tests and then `flutter test` exit successfully before publishing.
- No dependency versions or unrelated features change.
