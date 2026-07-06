# Backend & Windows publisher integration pass — design

Date: 2026-07-06
Issue: [#10](https://github.com/vitorhugo-java/flutter_SonicRelay/issues/10)

## Goal

Final integration pass across the Flutter viewer, the backend control-plane
([dotnet_SonicRelay](https://github.com/vitorhugo-java/dotnet_SonicRelay)) and the
Windows publisher ([windows_SonicRelay](https://github.com/vitorhugo-java/windows_SonicRelay)).

Fix only the integration problems found during the pass — do not rewrite the app.
Verify the HTTP contracts (auth, devices, sessions), the WebSocket signaling
contract and the WebRTC offer/answer/ICE flow against the authoritative backend
source, and document the real tested flow plus known limitations.

## Method

The backend is the authoritative contract. Its endpoints, the signaling
WebSocket handler and the documented `docs/protocol.md` were read directly from
source and compared field-by-field against the Flutter client's request/response
DTOs and signaling envelope. Backend integration tests were used to resolve
ambiguities (e.g. trailing-slash routing). The Windows publisher source was read
to confirm the peer handshake ordering and to surface cross-repo mismatches.

Because no live backend or publisher runs in CI, verification is static contract
alignment plus unit tests, `flutter analyze` and an Android build — not a live
end-to-end audio session.

## Contract verification results

### Auth — OK
`MapIdentityApi<ApplicationUser>` under `/auth`. `POST /auth/login?useCookies=false`
returns the framework `AccessTokenResponse`
`{tokenType, accessToken, expiresIn, refreshToken}`, which matches
`LoginResponse.fromJson`. `POST /auth/refresh {refreshToken}` and `GET /auth/me`
(`id, email, displayName, emailConfirmed, createdAt, lastLoginAt`) match.
`POST /auth/logout` returns 204.

### Devices — OK
`POST /api/devices` with `{name, type, platform, publicKey?}` → `201` with the
device response. Valid pairs: `flutter_viewer`/`android|ios`. The backend group
maps `MapPost("/")`, but its own integration tests `POST /api/devices` (no
trailing slash) and receive `201`, confirming the Flutter path is correct.

### Sessions join — MISMATCH (fixed on the Flutter side)
Backend `POST /api/sessions/join {code, deviceId}` returns a **StreamSession**:
`{id, ownerUserId, sourceDeviceId, status, maxViewers, codeExpiresAt, startedAt,
endedAt, createdAt, code}`.

The Flutter client expected `{sessionId, role, signalingUrl}` and threw
`FormatException` when they were absent — so **every real join failed** with an
`invalidResponse` error. There is no `signalingUrl` in the contract at all: the
signaling endpoint is the fixed route `GET /ws/signaling`, and the client is
responsible for building that URL from its configured WebSocket base URL.

Fix: parse `id` as the session id, drop `role` (the viewer role is implicit), map
the `status` string, and construct `signalingUrl` from `AppConfig.webSocketBaseUrl`
+ `/ws/signaling`.

### WebSocket signaling admission — OK
`GET /ws/signaling?sessionId={uuid}&deviceId={uuid}` with `Authorization: Bearer`.
The client appends `sessionId`/`deviceId` query params and the bearer header —
correct.

### Signaling readiness handshake — MISMATCH (fixed on the Flutter side)
Per `docs/protocol.md`, `viewer.ready` is a **routed** message that requires a
`to` participant UUID; sending it without a recipient returns
`error: invalid_recipient`. The documented viewer flow is: on `publisher.ready`,
learn the publisher's participant id from the authenticated `from` field and
reply `viewer.ready` **to that participant**. The publisher only creates the peer
connection and sends `webrtc.offer` after it receives that `viewer.ready`.

The Flutter client instead sent `viewer.ready` with no `to`, immediately on socket
open — rejected by the backend, and never triggering an offer.

Fix: stop auto-sending `viewer.ready` on connect. Emit it from the WebRTC receiver
in response to `publisher.ready`, addressed to that message's `from`.

### WebRTC offer / answer / ICE envelope — OK
Server-routed frames carry `{type, messageId, sessionId, from, to, timestamp,
payload}`. The receiver reads the offer `from` as the publisher participant id and
addresses `webrtc.answer` / `webrtc.ice_candidate` back to it. Payloads
(`{type, sdp}` and `{candidate, sdpMid, sdpMLineIndex}`) match the documented
opaque shapes.

## Cross-repo mismatch (documented, not fixable here)

The Windows publisher's `SignalingMessageEnvelope` serializes a `viewerId`
property and sends `publisher.ready` with no recipient, whereas the backend routes
strictly on `to`/`from` participant UUIDs. Until the publisher aligns its envelope
with the backend protocol, end-to-end audio will not establish even with a correct
viewer. Tracked against
[windows_SonicRelay](https://github.com/vitorhugo-java/windows_SonicRelay); see
`docs/troubleshooting.md`.

## Scope boundaries

Not in scope for this pass (documented as known limitations):
- Auto-wiring the join → open-signaling → navigate-to-listener UI flow.
- TURN/relay configuration (only public STUN is bundled).
- A live end-to-end audio run (no backend/publisher in CI).

## Acceptance criteria

- `flutter analyze` passes.
- `flutter test` passes.
- Android build still works.
- The manual integration flow and known limitations are documented.
- Cross-repo contract mismatches are documented with repository links.
