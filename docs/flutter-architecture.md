# Flutter architecture

The viewer follows Feature Driven Development (FDD): reusable technical
infrastructure in `core`, app wiring in `app`, and user-facing capabilities as
self-contained `features` with `data` / `domain` / `presentation` boundaries.

## Layers

```
lib/
  app/        bootstrap, router (go_router), theme, env config, Riverpod providers
  core/       http (Dio + auth interceptor), storage (secure), websocket, webrtc, widgets
  features/
    auth/       login, token session, /auth/* contract
    devices/    device registration and identity (/api/devices)
    sessions/   join a session by code (/api/sessions/join)
    signaling/  authenticated WebSocket signaling transport + typed envelope
    listener/   receive-only WebRTC + audio playback + the listener UI
    settings/   account/device settings
  main.dart
```

- **Riverpod** composes state and dependencies (`lib/app/di/app_providers.dart`).
- **go_router** guards navigation; all routes except `/login` require an
  authenticated session.
- **Dio** carries HTTP with an `AuthInterceptor` that injects the bearer token and
  performs a single refresh-and-retry on `401`.
- **flutter_secure_storage** backs both the token store and the device-id store;
  tokens and ids are never written to SharedPreferences or logs.
- **flutter_webrtc** provides the receive-only peer connection behind a thin,
  testable adapter.

## The signaling / WebRTC seam

The transport and protocol are deliberately split so each is independently
testable:

- `core/websocket/WebSocketClient` — reusable, reconnecting JSON-over-WebSocket
  transport with exponential backoff. Knows nothing about signaling.
- `features/signaling/SignalingClient` — builds the authenticated URL, maps frames
  through `SignalingMessageMapper` into typed `SignalingMessage`s, replies to
  `ping` with `pong`, forwards outbound messages (each addressed via `to`), and
  stops reconnecting on `session.ended`/leave.
- `features/listener/data/WebRtcReceiverService` — the receive-only peer-connection
  state machine. It is **signaling-agnostic**: inbound protocol messages arrive via
  `handleSignal`, and the answers/candidates it produces (plus the `viewer.ready`
  reply to `publisher.ready`) are emitted on `outboundSignals`.
- `features/listener/presentation/ListenerViewModel` — bridges the two: it pipes
  `SignalingClient.messages` into the receiver and forwards
  `receiver.outboundSignals` back out through `SignalingClient.send`, and exposes
  connection state + coarse stats to `ListenerPage`.

This seam is why the two integration fixes in the 2026-07-06 pass were localized:
the join-response shape lives entirely in `features/sessions`, and the
`viewer.ready` handshake correction lives entirely in the signaling/receiver seam
(`SignalingClient` stopped auto-sending it; `WebRtcReceiverService` now emits it in
reply to `publisher.ready`).

## Security posture

- Media is peer-to-peer (or via TURN); the backend routes only signaling JSON and
  is never a media relay.
- SDP and ICE candidate payload bodies are never logged anywhere in the transport
  or the receiver.
- The viewer is receive-only: it never captures a microphone, never adds a local
  track, and never handles video.

## Related docs

- [integration-flow.md](integration-flow.md) — the verified end-to-end contract.
- [troubleshooting.md](troubleshooting.md) — failure modes and the cross-repo mismatch.
