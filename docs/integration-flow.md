# Integration flow

The verified end-to-end contract between the Flutter viewer, the backend
control-plane ([dotnet_SonicRelay](https://github.com/vitorhugo-java/dotnet_SonicRelay))
and the Windows publisher
([windows_SonicRelay](https://github.com/vitorhugo-java/windows_SonicRelay)),
as checked during the 2026-07-06 integration pass.

The backend is the authoritative contract. All request/response shapes below were
verified against the backend endpoint source and `docs/protocol.md`, cross-checked
with the backend integration tests, and confirmed against the Flutter client's
DTOs and signaling envelope.

## Configuration

| Dart define | Default | Purpose |
| --- | --- | --- |
| `SONIC_RELAY_API_URL` | `http://localhost:5000` | HTTP API base URL |
| `SONIC_RELAY_WS_URL` | `ws://localhost:5000` | WebSocket base URL |

The signaling URL is **not** returned by the API. The client builds it as
`<SONIC_RELAY_WS_URL>/ws/signaling` (`AppConfig.signalingUri`) and the signaling
client appends `sessionId`/`deviceId`.

Use `https://` / `wss://` in production.

## End-to-end sequence

The MVP happy path — the publisher creates the session and connects first, then
the viewer joins:

1. **Login (viewer).** `POST /auth/login?useCookies=false` with `{email, password}`.
   Response: `{tokenType, accessToken, expiresIn, refreshToken}` (opaque bearer
   tokens, not a JWT). Stored via `flutter_secure_storage`.
2. **Register the viewer device.** `POST /api/devices` with
   `{name, type:"flutter_viewer", platform:"android"|"ios", publicKey?}` →
   `201` with the device record. The device UUID is stored separately from tokens.
3. **Create a session (Windows publisher).** The publisher calls
   `POST /api/sessions/` with `{sourceDeviceId}` and shows the six-character code.
4. **Join (viewer).** `POST /api/sessions/join` with `{code, deviceId}`. Response is
   the full session record (`id`, `status`, `code`, …). The client reads `id` as
   the session id and builds the signaling URL from config.
5. **Open signaling (viewer).**
   `GET /ws/signaling?sessionId={id}&deviceId={deviceId}` with
   `Authorization: Bearer <access_token>`. The server admits the socket, sends the
   viewer its own `session.joined` (its participant id), and broadcasts the
   viewer's `session.joined` to the already-connected publisher.
6. **Readiness handshake.** The publisher learns of the viewer and sends
   `publisher.ready` to the viewer's participant. The viewer reads the publisher's
   participant id from the authenticated `from` field and replies
   `viewer.ready` addressed to it.
7. **Offer.** On `viewer.ready`, the publisher creates the peer connection and
   sends `webrtc.offer` (`payload: {type:"offer", sdp}`) to the viewer.
8. **Answer.** The viewer applies the remote description, creates an answer, sets
   the local description and sends `webrtc.answer`
   (`payload: {type:"answer", sdp}`) back to the publisher.
9. **ICE.** Both sides trickle `webrtc.ice_candidate`
   (`payload: {candidate, sdpMid, sdpMLineIndex}`) to each other. Candidates that
   arrive before the remote description is set are buffered and flushed.
10. **Audio.** The remote audio track plays through the device output.
11. **Leave.** On `session.ended`, when the viewer leaves, or on device
    de-authorization, the peer connection and audio are torn down and the socket
    is closed.

## Verified HTTP contracts

| Method | Route | Request | Response (viewer-relevant) |
| --- | --- | --- | --- |
| `POST` | `/auth/login?useCookies=false` | `{email, password}` | `{tokenType, accessToken, expiresIn, refreshToken}` |
| `POST` | `/auth/refresh` | `{refreshToken}` | same as login |
| `GET` | `/auth/me` | — | `{id, email, displayName, emailConfirmed, createdAt, lastLoginAt}` |
| `POST` | `/auth/logout` | — | `204` |
| `POST` | `/api/devices` | `{name, type, platform, publicKey?}` | `201` device record |
| `GET` | `/api/devices` | — | device record list |
| `GET` | `/api/devices/{deviceId}` | — | device record or `404` |
| `POST` | `/api/sessions/join` | `{code, deviceId}` | session record `{id, status, code, …}` |

A `401` on any authenticated request triggers a single `POST /auth/refresh` and a
retry; if refresh fails, tokens are cleared and the app returns to `/login`.

## Verified signaling envelope

Every server frame:

```json
{
  "type": "webrtc.offer",
  "messageId": "<uuid>",
  "sessionId": "<uuid>",
  "from": "<sender-participant-uuid>",
  "to": "<recipient-participant-uuid>",
  "timestamp": "2026-07-06T14:00:00Z",
  "payload": {}
}
```

A client only needs to send `type`, `to`, `payload` and optionally `messageId`;
the server derives `sessionId`, overwrites `from` with the authenticated
participant and assigns the timestamp. **`to` is a participant id** — not a user,
device or session id.

Routed types requiring a `to`: `publisher.ready`, `viewer.ready`, `webrtc.offer`,
`webrtc.answer`, `webrtc.ice_candidate`, `pong`. `ping` needs no recipient.
Server-generated types: `session.joined`, `session.left`, `session.ended`,
`error`. Unknown types are preserved and forwarded, never dropped.

## What was fixed in this pass (Flutter side)

- **Join response parsing.** The client previously required `sessionId`/`role`/
  `signalingUrl` and threw on every real join. It now parses the backend `id`,
  maps `status`, and builds the signaling URL from config.
- **`viewer.ready` handshake.** The client previously sent `viewer.ready` with no
  `to`, on socket open — which the backend rejects (`invalid_recipient`). It now
  sends `viewer.ready` in reply to `publisher.ready`, addressed to that message's
  `from` participant.

See [troubleshooting.md](troubleshooting.md) for the outstanding cross-repo
mismatch and other failure modes.
