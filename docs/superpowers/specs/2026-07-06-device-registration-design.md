# Device Registration and Listing Design

## Goal

Register the authenticated Flutter installation as a `flutter_viewer`, persist its backend-issued device ID, and expose the user's devices in Settings.

## Decisions

- Keep all device behavior under `lib/features/devices`; application composition only wires providers.
- Use the existing authenticated `Dio` instance. The feature never reads or writes auth tokens.
- Persist the backend UUID behind `DeviceIdStorage`, implemented with `FlutterSecureStorage`. The display name is a label only and is never used to identify the installation.
- Detect Android/iOS through a provider so production uses `dart:io` while tests remain deterministic.
- On authentication, `DevicesViewModel` calls `ensureCurrentDevice`. A stored ID is validated with `GET /api/devices/{id}` and reused when active; missing or revoked records are replaced with `POST /api/devices` and the returned ID is persisted.
- Registration uses type `flutter_viewer`, platform `android` or `ios`, and a stable generic display label (`SonicRelay Android Viewer` or `SonicRelay iOS Viewer`). Unsupported platforms surface a friendly error and do not send an invalid request.
- Settings requests `GET /api/devices` and renders each result with `DeviceCard`, including current/trusted/revoked state.

## Data Model and API

`DeviceResponse` maps the backend contract (`id`, `name`, `type`, `platform`, `publicKey`, `trusted`, `revoked`, `lastSeenAt`, `createdAt`) into the immutable domain `Device`. `DevicesApi` owns only HTTP serialization. `DevicesRepository` owns mapping, local-ID validation, registration, and friendly failure translation.

## State and Errors

`DevicesState` carries registration/list loading flags, the current device ID, device list, and an optional friendly error. Authentication remains valid if registration is temporarily unavailable; retrying Settings refresh re-attempts registration and listing.

## Testing

- Repository mapping and list behavior.
- First registration persists the returned UUID and sends the required type/platform.
- Existing active local ID is reused without POST; a missing record is re-registered.
- `DeviceCard` renders identity and status.
- Run only device/auth/app tests during development, then `flutter analyze` and `flutter test` as the issue's explicit acceptance gates.

## Scope

No update/delete UI, public-key generation, session join, signaling, dependency upgrades, or unrelated refactoring.
