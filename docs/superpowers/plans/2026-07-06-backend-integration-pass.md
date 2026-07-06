# Backend & Windows publisher integration pass — plan

Date: 2026-07-06
Spec: [2026-07-06-backend-integration-pass-design.md](../specs/2026-07-06-backend-integration-pass-design.md)
Issue: [#10](https://github.com/vitorhugo-java/flutter_SonicRelay/issues/10)

## Steps

1. **Session join contract fix**
   - `AppConfig`: add `signalingUri` that returns `<webSocketBaseUrl>/ws/signaling`
     (tolerating a trailing slash in the base URL).
   - `SessionStatus`: add `fromWire(String)` mapping `active` → `connected`,
     everything else → `waiting`.
   - `StreamSession`: drop `role`; keep `sessionId`, `signalingUrl`, `status`.
   - `JoinSessionResponse`: parse the real backend body (`id`, `status`, `code`);
     `toDomain(Uri signalingUrl)` validates the ws/wss scheme and builds the
     domain session.
   - `SessionsRepository`: take `AppConfig`, build the signaling URL and pass it to
     `toDomain`.
   - `app_providers`: inject `AppConfig` into `SessionsRepository`.
   - `session_waiting_page`: drop the `Role:` line.

2. **Viewer-ready handshake fix**
   - `SignalingClient`: remove the auto `viewer.ready` send on socket open (keep the
     `send()` API and pong handling).
   - `WebRtcReceiverService.handleSignal`: on `publisher.ready`, record the
     publisher id from `from`, emit `viewer.ready` addressed to it, and move to
     `waitingForOffer`.

3. **Tests**
   - New `join_session_response_test`: lock the backend body → domain mapping and
     the missing-`id` failure.
   - Update `sessions_repository_test`, `join_session_view_model_test`,
     `listener_view_model_test`, `signaling_client_test` for the new
     `StreamSession`/`JoinSessionResponse` shape and the removed auto-`viewer.ready`.
   - Update `webrtc_receiver_service_test`: `publisher.ready` now emits a
     `viewer.ready` outbound signal addressed to the publisher.

4. **Docs**
   - `docs/integration-flow.md`: the verified end-to-end flow and contracts.
   - `docs/troubleshooting.md`: common failures and the cross-repo mismatch.
   - `docs/flutter-architecture.md`: FDD layout and the signaling/WebRTC seam.
   - `README.md`: tested flow, configuration env vars, known limitations, repo links.

5. **Verification**
   - `flutter analyze`, `flutter test`, `flutter build apk --debug`.

6. **Ship**: commit to `main`, push, close issue #10.
