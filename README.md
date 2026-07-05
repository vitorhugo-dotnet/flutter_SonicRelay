# SonicRelay Flutter Viewer

Mobile viewer for the low-latency SonicRelay audio streaming suite.

- [Backend](https://github.com/vitorhugo-java/dotnet_SonicRelay)
- [Windows publisher](https://github.com/vitorhugo-java/windows_SonicRelay)

## Architecture

The app uses Feature Driven Development:

- `lib/app`: bootstrap, router, theme, environment configuration, and dependency providers.
- `lib/core`: reusable technical infrastructure such as HTTP, secure storage, WebSocket, and WebRTC adapters.
- `lib/features`: user-facing capabilities. Each feature owns its `data`, `domain`, and `presentation` boundaries when applicable.

Riverpod provides state and dependency composition, go_router handles navigation, Dio provides HTTP infrastructure, and sensitive tokens will be stored with flutter_secure_storage. The flutter_webrtc package is installed, but real media behavior is intentionally not part of this foundation.

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

Initial routes are `/` (login), `/join`, `/listener`, and `/settings`.

## UI preview

The current app provides a dark Material 3 shell with reusable controls and presentation-only login, session join, listener, and settings screens. Backend authentication, session discovery, and WebRTC audio are intentionally not connected yet.

To capture Android screenshots, run an emulator, start the app with `flutter run`, navigate through the local preview actions, and use the emulator screenshot control. Recommended captures are the login screen and the listener dashboard at a common phone size such as 1080 × 2400.
