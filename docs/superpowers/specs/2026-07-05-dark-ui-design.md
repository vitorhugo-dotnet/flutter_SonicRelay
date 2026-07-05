# SonicRelay Dark UI Design

## Goal

Replace the bootstrap placeholders with a polished, dark-first Material 3 shell for the mobile viewer while keeping all backend and WebRTC behavior out of scope.

## Design

The UI uses a near-black navy surface, a restrained cyan accent, rounded cards, subtle borders and gradients, and a compact spacing scale. Content is mobile-first, safe-area aware, scrollable where needed, and capped at a readable maximum width on larger phones.

Foundation tokens live under `lib/app/theme`: colors define semantic surfaces and status tones, spacing provides a consistent scale, typography defines the app text theme, and `AppTheme` assembles the Material 3 dark theme. Shared controls under `lib/core/widgets` expose only page-level needs: buttons, cards, text fields, connection badges, and a loading overlay.

## Screens and Flow

- Login shows branding, email/password inputs, a primary sign-in action, and a future registration action. Sign-in navigates locally to `/join`; no credentials are processed.
- Join session shows a prominent session-code input, publisher guidance, and a local join action to `/listener`.
- Listener shows a disconnected/demo connection badge, decorative audio bars, latency and ICE placeholders, plus a leave action returning to `/join`.
- Settings shows API environment, appearance/status placeholders, and a logout action returning to `/`.

All displayed metrics and states are explicitly presented as preview values and remain inside presentation widgets. No fake domain models, repositories, services, network calls, or media behavior are introduced.

## Error Handling and Accessibility

The issue adds no fallible operations. Controls retain Material semantics and minimum touch sizes, inputs have labels, decorative visualizer bars are excluded from semantics, and foreground/background combinations use high contrast. The loading overlay blocks interaction and exposes a readable status label when used by future work.

## Testing

Widget tests verify the dark Material 3 theme, required content on all four routes, local navigation, reusable widget behavior, and representative small-phone rendering without overflow. Verification uses the smallest relevant test targets followed by `flutter analyze` and `flutter test`, as required by the issue.

## Scope

No dependencies, backend integration, WebRTC behavior, persistent state, validation rules, or unrelated architecture changes are included.
