# Signaling Client Design

## Goal

Implement an authenticated WebSocket signaling client for the Flutter viewer that connects using the session-join context, exchanges typed messages, and reconnects with backoff — without introducing any WebRTC peer connection.

## Decisions

- Split transport and feature logic: `lib/core/websocket` owns a reusable, schema-agnostic, reconnecting JSON-over-WebSocket client; `lib/features/signaling` owns everything specific to the SonicRelay signaling protocol.
- `WebSocketClient` exposes broadcast streams for connection state and raw messages, an injectable `WebSocketConnector` (`dart:io`-backed by default) and timer scheduler for deterministic tests, and exponential backoff (1s, capped at 30s) that only stops on an explicit `disconnect()`.
- `SignalingMessage` is a typed domain model (`type`, `messageId`, `sessionId`, `from`, `to`, `timestamp`, `payload`) used instead of raw dynamic maps. Unrecognized wire types map to `SignalingMessageType.unknown` (the original value is preserved) and are still forwarded, so the client tolerates future message types without crashing.
- `SignalingClient` builds the connection URI from `StreamSession.signalingUrl` (returned by `POST /api/sessions/join`) plus `sessionId`/`deviceId` query parameters, and sets the current access token as a Bearer header, read from the existing `TokenStorage` — no new auth logic is introduced.
- Behavior on top of the transport: send `viewer.ready` once connected, auto-reply `pong` to a server `ping`, forward every message to listeners, and on `session.ended` set state to `ended` and close the socket without reconnecting (same path as an explicit `leave()`).
- `SignalingStatusViewModel` (Riverpod `Notifier`) exposes connection status and the last routed message for a future listener UI. Wiring into `listener_page.dart` is explicitly out of scope for this issue.
- No SDP/ICE payload content is ever logged; no logging was added at all, keeping the surface area minimal and the constraint trivially satisfied.

## Components and data flow

1. A caller (a future listener feature) obtains the joined `StreamSession` and current `deviceId`, then calls `SignalingClient.connect(session, deviceId)`.
2. `SignalingClient` reads the access token, builds the URI, and calls `WebSocketClient.connect()` with the `Authorization` header.
3. `WebSocketClient` opens the socket via the injected connector, emits connection-state transitions, and forwards decoded frames as `WebSocketMessage`.
4. `SignalingMessageMapper` converts `WebSocketMessage` to/from `SignalingMessage`.
5. `SignalingClient` reacts to inbound types (`ping` → `pong`, `session.ended` → `ended` + `leave()`) and forwards every message on its own `messages` stream.
6. `SignalingStatusViewModel` mirrors connection state and the last message into Riverpod state for the UI layer.

## Tests

- Unit: `WebSocketMessage` encode/decode and malformed-frame handling.
- Unit: `WebSocketClient` state transitions, message forwarding, `send`, reconnect-with-backoff after a dropped connection, retry-until-success, and `disconnect` stopping further attempts (fake connector + injectable timer — no real sockets, no real delays).
- Unit: `SignalingMessageMapper` round-trip for every known message type and unknown-type handling.
- Unit: `SignalingClient` — URL/query params/auth header on connect, `viewer.ready` on open, `ping` → `pong`, `session.ended` closing the socket and stopping reconnects, and unknown types forwarded without throwing.

## Acceptance criteria

- All issue #6 requirements are represented in code and README documentation.
- `flutter analyze` exits successfully.
- `flutter test` exits successfully.
- No WebRTC peer connection code is introduced.
- No dependency versions or unrelated features change.
