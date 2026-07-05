# Flutter FDD Foundation Design

## Objective

Bootstrap SonicRelay as a runnable Flutter Material 3 application organized by user-facing feature, with Riverpod dependency injection, go_router navigation, and reusable HTTP and secure-storage infrastructure.

## Structure

`lib/app` owns startup-wide concerns: the root widget, router, theme, environment values, and providers. `lib/core` owns technical building blocks that are not user capabilities. `lib/features` owns capabilities; each feature reserves `data`, `domain`, and `presentation` boundaries and places its initial page in `presentation`.

## Runtime behavior

`main.dart` creates a `ProviderScope` and launches `SonicRelayApp`. The app reads a shared router and exposes four routes: login (`/`), join session (`/join`), listener (`/listener`), and settings (`/settings`). Placeholder pages make navigation visible without implementing backend or WebRTC behavior.

`AppConfig` reads `SONIC_RELAY_API_URL` and `SONIC_RELAY_WS_URL` from `--dart-define`, with local-development defaults. Riverpod providers construct Dio from the API URL and expose `FlutterSecureStorage` for future authentication tokens.

## Dependencies

Use `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, and `flutter_webrtc`. `flutter_lints` supplies static-analysis defaults. No package beyond the issue requirements is introduced.

## Verification

A widget test pumps the root app inside `ProviderScope`, verifies the login route, and navigates to the join-session route. Acceptance is demonstrated by `flutter pub get`, `flutter analyze`, and `flutter test`.

## Out of scope

Authentication, API calls, WebSocket signaling, media permissions, and real WebRTC sessions are intentionally deferred.
