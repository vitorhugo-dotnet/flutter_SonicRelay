# Persistent Connection and ICE Recovery Design

## Problem

Two independent defects combined to make an Android viewer session look like
Android was killing the app in the background. Neither is a background-execution
problem.

### 1. The signaling socket is reaped every ~90 seconds

Viewer diagnostics (2026-08-13) show `socket closed by peer` at a near-constant
period across two unrelated sessions:

```
92s · 91s · 90s · 89s · 90s · 94s · 106s · 90s · 90s · 90s · 90s
```

The publisher's log shows the mirror image — `ICE restart requested for a
reconnected viewer` at 92s, 91s, 99s, 107s.

The cause is an idle connection. After the WebRTC handshake completes the
signaling socket carries no traffic in either direction: the backend only
answers `pong` to a client `ping` (`SignalingWebSocketEndpoint.HandleMessageAsync`)
and never initiates one, and the Flutter client only answers a server `ping`
that never arrives (`SignalingClient._sendPong`). Across 390 logged events there
is not one `recv type=ping`. An intermediary reaps the idle socket.

The decisive evidence is the contrast between the two clients:

| Client | Keepalive | Observed lifetime |
|---|---|---|
| Windows publisher | `KeepAliveInterval = 20s` (`ClientWebSocketConnection.cs:24`) | 8+ minutes |
| Android viewer | none — `WebSocket.connect()` leaves `pingInterval` null (`websocket_client.dart:48`) | dies at ~90s, every time |

`dart:io`'s `WebSocket.pingInterval` defaults to null, so no keepalive frame is
ever sent. This is not a background problem: the socket died at 17:33:03 and
19:57:08 while the app was `resumed` and on screen.

The reap is made worse by `ListenerViewModel`, which calls `_receiver.reconnect()`
on *every* socket recovery without checking whether the peer connection is
healthy — throwing away a working WebRTC session every 90 seconds.

### 2. The publisher never re-offers to a known viewer

When ICE fails while signaling is healthy, the viewer disposes its peer
connection and asks for a new offer (`webrtc_receiver_service.dart:247-251`).
The publisher drops that request on the floor:

```csharp
// WebRtcPublisher.cs:127-128
var registration = await peers.RegisterViewerAsync(viewerId, cancellationToken);
if (!registration.WasCreated) return;
```

`RegisterViewerAsync` returns `WasCreated: false` whenever a peer already exists
for that viewer id (`PeerConnectionManager.cs:38-41`), and the participant id is
stable for the whole session. So the viewer waits for an offer that never comes.

The working ICE-restart path (`ReofferToViewerAsync`) is reachable only from
`participant.reconnected` — that is, only when the *signaling socket* dropped
and returned. A pure media/ICE failure with healthy signaling (Wi-Fi to cellular
handover, NAT rebinding) has no recovery path at all.

These two defects mask each other: the 90s socket reap generated a
`participant.reconnected` every 90 seconds, whose ICE restart accidentally
repaired dead media. **Fixing the keepalive alone would remove that accidental
repair and make ICE failure permanent**, so both fixes must ship together.

## Non-goals

- **Escalating to relay after direct-ICE failures.** Explicitly rejected: a user
  who chose not to use relay must never be silently switched to it. The existing
  behavior is already correct — `disableFallback` makes the backend omit TURN
  entries and `IceServersRepository._applyPreferences` drops any that remain, so
  there is nothing to escalate to. `automatic` already carries TURN candidates in
  the pool for ICE to select on its own.
- **Changing Android's background architecture.** The process-survival layer
  (process-lifetime `FlutterEngine`, `mediaPlayback` foreground service,
  `stopWithTask="false"`, partial wake lock) already exists from issues #13/#22
  and is not modified here.

## Changes

### A. Socket stability

**A1 — `flutter/lib/core/websocket/websocket_client.dart`**
`ioWebSocketConnector` sets `pingInterval` to 20s, matching the Windows
publisher. This alone ends the ~90s reap.

**A2 — `flutter/lib/features/listener/presentation/listener_view_model.dart`**
Re-announce `viewer.ready` on signaling recovery only when the receiver is not
already `connected`. A healthy peer connection is never renegotiated.

**A3 — `dotnet/services/SonicRelay.Api/Program.cs` and `infra/nginx/default.conf`**
`WebSocketOptions.KeepAliveInterval = 20s`, matching both clients (the ASP.NET
Core default of 2 minutes is longer than the ~90s reap window, so it never fired
— the integration test confirms that default), plus explicit
`proxy_read_timeout`/`proxy_send_timeout` on the WebSocket route, which currently
inherits nginx's 60s default. This protects every client, including already
installed app versions that lack A1.

The interval is configured through DI rather than passed to `UseWebSockets()`, so
the effective value is observable and can be asserted rather than assumed.

### B. ICE recovery

**B1 — `windows/src/SonicRelay.Windows.WebRtc/WebRtcPublisher.cs`**
A `viewer.ready` for an already-registered viewer performs an ICE restart and
re-offer instead of returning silently.

Only `viewer.ready` does this. A repeated `session.joined` is backend noise about
a presence already acted on rather than a request for anything, so it stays
deduped exactly as before — recovering on it would renegotiate on every
re-broadcast.

An ICE restart within 2s of the previous one for the same viewer is treated as a
duplicate (via an injected `TimeProvider`). Without that, a dropped viewer socket
would produce two offers: one from the publisher's own `participant.reconnected`
handler and one from the viewer's `viewer.ready`, with the answer to the first
still in flight when the second is created. Genuine recovery requests are seconds
to minutes apart, so the window never suppresses one — a test pins that a later
request restarts ICE again rather than the debounce spending the viewer's single
recovery.

**B2 — `flutter/lib/core/webrtc/ice_servers_repository.dart`**
Log explicitly when the resolved ICE server list is empty. In release builds a
failed fetch with a cold cache yields an empty list (`allowGoogleStunDevFallback`
is `kDebugMode`), leaving only host candidates and no way through NAT. That is
the intended policy — no production path depends on Google's public STUN — but
it currently fails in complete silence.

### C. Diagnostics

**C1 — `flutter/lib/core/diagnostics/sonic_log.dart`**
`sonicLog` writes only to `debugPrint`, so the `Background` and `WebRTC`
categories never reach the exportable diagnostic log — which is why the uploaded
log contains only `Signaling`, `Lifecycle` and `WebSocket`. Add an optional sink
that `main()` points at the `DiagnosticLog`, so foreground-service and
peer-connection behavior can be confirmed on-device.

**C2 — `flutter/lib/features/listener/data/webrtc_receiver_service.dart`**
Log the selected ICE candidate path (host/srflx/relay) on connect, so whether
media is actually relayed is observable rather than inferred.

## Tests

- `websocket_client_test.dart` — the io connector applies the keepalive interval.
- `listener_view_model_test.dart` — signaling recovery re-announces readiness
  when the receiver is disconnected, and does not when it is connected.
- `WebRtcPublisherTests` — a repeated `viewer.ready` after the debounce window
  triggers an ICE restart and a second offer; within the window it does not;
  a viewer with no existing peer still gets a normal first offer.
- `ice_servers_repository_test.dart` — an empty resolved list is logged.
- `sonic_log_test.dart` — messages reach an installed sink.

`ViewerReadyRegistersPeerAndSendsOfferOnlyOnce` asserts the current defective
behavior and is rewritten as part of B1.

## Acceptance criteria

- `flutter analyze` and `flutter test` exit 0; `dotnet test` passes in both
  .NET repos.
- An idle viewer session survives well past 90 seconds without a socket close.
- A viewer whose ICE fails while signaling is up receives a fresh offer and
  recovers.
- A user on `disableFallback` is never given a TURN server by any code path.
