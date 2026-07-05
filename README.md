# SonicRelay Flutter Viewer

Mobile viewer for the low-latency SonicRelay audio streaming suite.

- [Backend](https://github.com/vitorhugo-java/dotnet_SonicRelay)
- [Windows publisher](https://github.com/vitorhugo-java/windows_SonicRelay)

## Architecture

The app uses Feature Driven Development:

- `lib/app`: bootstrap, router, theme, environment configuration, and dependency providers.
- `lib/core`: reusable technical infrastructure such as HTTP, secure storage, WebSocket, and WebRTC adapters.
- `lib/features`: user-facing capabilities. Each feature owns its `data`, `domain`, and `presentation` boundaries when applicable.

Riverpod provides state and dependency composition, go_router handles guarded navigation, Dio provides HTTP infrastructure, and sensitive tokens are stored only through a flutter_secure_storage-backed abstraction. The flutter_webrtc package is installed, but real media behavior is intentionally not part of this foundation.

## Local development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Override the local backend endpoints with dart defines:

```sh
flutter run \
  --dart-define=SONIC_RELAY_API_URL=https://api.example.com \
  --dart-define=SONIC_RELAY_WS_URL=wss://api.example.com
```

Routes are `/login`, `/join`, `/listener`, and `/settings`. All routes except `/login` are protected; startup restores a stored session before deciding which route to show.

## Backend authentication contract

The configured API must expose:

```text
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
GET  /auth/me
```

Login uses the ASP.NET Identity bearer-token contract. Access and refresh tokens are persisted through `TokenStorage` backed by `flutter_secure_storage`; they are never written to SharedPreferences or logs. A `401` response triggers one refresh attempt and retries the original request. If refresh fails, local tokens are cleared and the app returns to `/login`.

`SONIC_RELAY_API_URL` is required for a deployed backend. The localhost value in `AppConfig` is intended only for local development; production URLs are not embedded in the app.

## UI preview

The current app provides a dark Material 3 shell with reusable controls and connected token authentication. Session discovery and WebRTC audio are not connected yet.

To capture Android screenshots, run an emulator, start the app with `flutter run`, navigate through the local preview actions, and use the emulator screenshot control. Recommended captures are the login screen and the listener dashboard at a common phone size such as 1080 × 2400.
