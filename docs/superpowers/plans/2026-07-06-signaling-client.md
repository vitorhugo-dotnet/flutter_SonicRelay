# Signaling Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement an authenticated WebSocket signaling client for the Flutter viewer, covering signaling transport and typed message routing only.

**Architecture:** A schema-agnostic, reconnecting WebSocket transport lives in `lib/core/websocket`; SonicRelay-specific signaling behavior (typed messages, `viewer.ready`, ping/pong, `session.ended`) lives in `lib/features/signaling` and composes the transport plus the existing token storage and session-join context.

**Tech Stack:** Dart, Flutter, Riverpod, `dart:io` WebSocket, flutter_test

---

### Task 1: Core WebSocket transport

**Files:**
- Create: `lib/core/websocket/websocket_message.dart`
- Create: `lib/core/websocket/websocket_client.dart`
- Create: `test/core/websocket/websocket_message_test.dart`
- Create: `test/core/websocket/websocket_client_test.dart`

- [x] Write transport tests using a fake connector/connection and an injectable timer: connecting/connected states, message forwarding, `send`, reconnect-with-backoff after a drop, retry-until-success, and disconnect stopping further attempts.
- [x] Run the targeted tests; confirm RED because the transport classes do not exist.
- [x] Implement `WebSocketMessage` (raw JSON-object frame) and `WebSocketClient` (connection-state/message broadcast streams, exponential backoff capped at 30s, `dart:io`-backed default connector, explicit `disconnect()`/`dispose()`).
- [x] Re-run the targeted tests; confirm GREEN.

### Task 2: Signaling domain and mapper

**Files:**
- Create: `lib/features/signaling/domain/signaling_message_type.dart`
- Create: `lib/features/signaling/domain/signaling_message.dart`
- Create: `lib/features/signaling/data/signaling_message_mapper.dart`
- Create: `test/features/signaling/data/signaling_message_mapper_test.dart`

- [x] Write mapper tests for a known envelope, round-trip serialization of every message type, unrecognized-type handling (mapped to `unknown` with the raw value preserved), and malformed/partial frames.
- [x] Run the targeted test; confirm RED because the domain/mapper types do not exist.
- [x] Implement `SignalingMessageType` (the ten protocol types plus `unknown`), the immutable `SignalingMessage` envelope, and `SignalingMessageMapper` converting to/from `WebSocketMessage`.
- [x] Re-run the targeted test; confirm GREEN.

### Task 3: Signaling client behavior

**Files:**
- Create: `lib/features/signaling/data/signaling_client.dart`
- Create: `test/features/signaling/data/signaling_client_test.dart`

- [x] Write tests proving: the connection URI carries `sessionId`/`deviceId` query params and a Bearer auth header from `TokenStorage`; `viewer.ready` is sent once the socket opens; a server `ping` triggers an automatic `pong`; `session.ended` closes the socket and moves state to `ended`/`disconnected` without reconnecting; unknown message types are forwarded without throwing.
- [x] Run the targeted test; confirm RED because `SignalingClient` does not exist.
- [x] Implement `SignalingClient` composing `WebSocketClient` + `TokenStorage`, building the authenticated URI from the joined `StreamSession`, and routing inbound messages per the behaviors above.
- [x] Re-run the targeted test; confirm GREEN.

### Task 4: Presentation state and application wiring

**Files:**
- Create: `lib/features/signaling/presentation/signaling_status_view_model.dart`
- Modify: `lib/app/di/app_providers.dart`

- [x] Add `webSocketClientProvider` and `signalingClientProvider` following the existing `Provider`-based composition pattern.
- [x] Implement `SignalingStatusViewModel` (Riverpod `Notifier`) exposing connection status and the last routed message for a future listener UI; wiring into `listener_page.dart` is intentionally left out of scope for this issue.

### Task 5: Documentation and acceptance verification

**Files:**
- Modify: `README.md`

- [x] Document the `/ws/signaling` endpoint, the typed envelope, the supported message types (including the `unknown` fallback), and the transport/signaling split in README.
- [x] Run `flutter test test/core/websocket test/features/signaling`; confirm zero failures.
- [x] Run `flutter analyze`; confirm exit code 0.
- [x] Run `flutter test`; confirm exit code 0, as explicitly required by issue #6.
- [x] Review the scoped diff against issue #6; confirm no WebRTC peer-connection code was introduced.
- [x] Commit the scoped files on `main` (`af38550`: "feat: implement authenticated WebSocket signaling client"), push `origin/main`, and confirm issue #6 auto-closed via the `Closes #6` commit reference.
