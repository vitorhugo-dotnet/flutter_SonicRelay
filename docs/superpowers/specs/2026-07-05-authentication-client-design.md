# Authentication Client Design

## Goal

Connect the Flutter viewer to the backend ASP.NET Identity token endpoints, persist credentials securely, restore sessions at startup, refresh expired access tokens, and guard authenticated routes.

## Contract

- `POST /auth/login` receives `email` and `password` and returns `accessToken`, `refreshToken`, `expiresIn`, and `tokenType`.
- `POST /auth/refresh` receives `refreshToken` and returns a replacement token pair.
- `POST /auth/logout` invalidates the current server session when reachable.
- `GET /auth/me` returns the authenticated user's `id`, `email`, `displayName`, and account metadata.

## Architecture

The auth feature retains FDD boundaries. DTOs and the Dio API adapter live in `data`, immutable session/user values live in `domain`, and `AuthViewModel` owns startup restoration, login, logout, and user-facing error state in `presentation`. Widgets only validate input and invoke the view model.

`TokenStorage` is the only token persistence boundary. Its production implementation delegates to `flutter_secure_storage`; tests use an in-memory fake. Dio receives an auth interceptor that adds bearer credentials, serializes concurrent refresh attempts, retries a failed request once, and clears credentials plus notifies auth state when refresh fails. Auth endpoints themselves bypass interception where recursion would be unsafe.

The router is provided through Riverpod. Its redirect reads auth state and refreshes whenever that state changes: unauthenticated users are restricted to `/login`, authenticated users are redirected from `/login` to `/join`, and restoration displays a neutral loading route.

## Errors and security

HTTP 400/401 login failures become a friendly credentials message; transport failures become a connection message. Tokens and raw responses are never logged. Logout clears local credentials even if the backend call fails. All base URLs come from `AppConfig` dart defines.

## Verification

Targeted tests cover the storage contract, repository login/refresh/logout behavior, route protection, and login validation. Final verification runs `flutter analyze` and `flutter test`, as required by the issue.
