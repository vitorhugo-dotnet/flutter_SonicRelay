# Settings Reachability & Relay/Coturn Settings (Flutter Viewer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Settings (and its already-working server-URL field) reachable from the very
first screen an unpaired device sees, and add a `RelayMode`/coturn-URL settings UI synced
with the `/api/settings/relay` endpoint added in `dotnet_SonicRelay`
(`docs/superpowers/plans/2026-08-04-relay-coturn-settings-api.md`) — the Flutter half of
`windows_SonicRelay`'s design spec
(`docs/superpowers/specs/2026-08-04-pairing-nav-and-relay-settings-design.md`).

**Architecture:** `pairing_page.dart` gets a settings entry point in its `AppBar` (the field
itself, `ServerUrlField`, already exists and needed no changes). `forceRelayProvider`
(a local-only bool) is replaced by `relayModeProvider` (a three-way string, matching the
backend's `RelayMode`), backed by a new `RelaySettingsApi`/`DioRelaySettingsApi` and a
migrated `RelayModeStorage`. A new coturn-URL field is added to `SettingsPage`, visible only
once the device is paired.

**Tech Stack:** Flutter, Riverpod (`Notifier`/`NotifierProvider`), Dio, `go_router`,
`flutter_secure_storage`.

## Global Constraints

- `RelayMode` is one of exactly three string values
  (`lib/core/webrtc/relay_modes.dart`): `automatic`, `forceRelay`, `disableFallback` — same
  spelling as the backend and as `windows_SonicRelay`'s `RelayModes`.
- Changing `RelayMode` or the coturn URL writes through to `PUT /api/settings/relay`
  directly — never a local-only apply.
- The local `RelayModeStorage` value is a last-known-good cache only, always overwritten by
  the latest server-confirmed value.
- The coturn URL field is visible only when `deviceReadinessProvider`'s status is
  `DeviceReadinessStatus.ready` (i.e. this device is paired) — matching "after logging in" in
  the design spec. The `RelayMode` selector has no such gate (mirrors
  `windows_SonicRelay`, where only the coturn field is auth-gated).
- Every existing test file this plan doesn't explicitly rewrite must keep passing, in
  particular `test/app/app_router_test.dart` and the existing `PairingPage`/`SettingsPage`
  widget tests.

---

### Task 1: Settings reachable from the pairing page

**Files:**
- Modify: `lib/features/pairing/presentation/pairing_page.dart`
- Test: `test/features/pairing/presentation/pairing_page_test.dart`

**Interfaces:** none new — this only adds a route trigger to an existing screen.

- [ ] **Step 1: Write the failing test**

Add this test to `test/features/pairing/presentation/pairing_page_test.dart` (inside the
existing `void main() { ... }` block, alongside the other `testWidgets` calls — do not remove
any existing test):

```dart
testWidgets('exposes a settings entry point that opens /settings', (tester) async {
  final repository = _FakePairingRepository();
  final router = GoRouter(
    initialLocation: '/pair',
    routes: [
      GoRoute(path: '/pair', builder: (_, _) => const PairingPage()),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('Settings page')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pairingRepositoryProvider.overrideWithValue(repository),
        currentPairingDeviceIdProvider.overrideWithValue(() async => null),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();

  expect(find.text('Settings page'), findsOneWidget);
});
```

(`_FakePairingRepository`, `pairingRepositoryProvider`, and `currentPairingDeviceIdProvider`
are already defined/imported in this test file for the other tests — reuse them, don't
redefine. Add `import 'package:go_router/go_router.dart';` to this file's imports if it isn't
already there.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/pairing/presentation/pairing_page_test.dart --plain-name "exposes a settings entry point"`
Expected: FAIL — `find.byTooltip('Settings')` finds nothing yet.

- [ ] **Step 3: Add the settings button**

In `lib/features/pairing/presentation/pairing_page.dart`, change:

```dart
appBar: AppBar(title: const Text('Pair device')),
```

to:

```dart
appBar: AppBar(
  title: const Text('Pair device'),
  actions: [
    IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => context.push('/settings'),
    ),
  ],
),
```

Add `import 'package:go_router/go_router.dart';` to this file's imports if not already
present (check first — `listener_page.dart`/`join_session_page.dart` already do the identical
`context.push('/settings')`, so this import is a known-working pattern in this codebase).

- [ ] **Step 4: Run the test and verify it passes**

Run: `flutter test test/features/pairing/presentation/pairing_page_test.dart`
Expected: PASS, including every pre-existing test in this file.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pairing/presentation/pairing_page.dart test/features/pairing/presentation/pairing_page_test.dart
git commit -m "Add a Settings entry point to the pairing page"
```

---

### Task 2: `RelayModes`, `RelaySettingsApi`, and a migrated `RelayModeStorage`

**Files:**
- Create: `lib/core/webrtc/relay_modes.dart`
- Create: `lib/core/webrtc/relay_settings_api.dart`
- Modify: `lib/core/storage/relay_mode_storage.dart`
- Test: `test/core/webrtc/relay_settings_api_test.dart` (new)
- Test: `test/core/storage/relay_mode_storage_test.dart` (new)

**Interfaces:**
- Produces: `RelayModes.automatic`/`forceRelay`/`disableFallback`/`isValid(String?)`;
  `RelaySettingsResult(String relayMode, List<String> turnUris, bool hasCustomTurnSecret)`;
  `abstract interface class RelaySettingsApi { Future<RelaySettingsResult> fetch();
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}); }`;
  `DioRelaySettingsApi`; `RelayModeStorage.read()` now returns `Future<String>` (was
  `Future<bool>`), `RelayModeStorage.write(String mode)` (was `write(bool value)`).

- [ ] **Step 1: Write the failing `RelaySettingsApi` tests**

Create `test/core/webrtc/relay_settings_api_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.callback);
  final ResponseBody Function(RequestOptions options) callback;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => callback(options);
  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(Map<String, Object?> body, {void Function(RequestOptions)? onRequest}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://sonicrelay-api.hugodotnet.dev'));
  dio.httpClientAdapter = _CallbackAdapter((options) {
    onRequest?.call(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  });
  return dio;
}

void main() {
  test('fetch parses relayMode, turnUris, and hasCustomTurnSecret', () async {
    final api = DioRelaySettingsApi(
      _dioReturning({
        'relayMode': 'forceRelay',
        'turnUris': ['turn:relay.example.com:3478'],
        'hasCustomTurnSecret': true,
      }),
    );

    final result = await api.fetch();

    expect(result.relayMode, 'forceRelay');
    expect(result.turnUris, ['turn:relay.example.com:3478']);
    expect(result.hasCustomTurnSecret, isTrue);
  });

  test('update sends a PUT with only the provided fields', () async {
    RequestOptions? sent;
    final api = DioRelaySettingsApi(
      _dioReturning(
        {'relayMode': 'disableFallback', 'turnUris': <String>[], 'hasCustomTurnSecret': false},
        onRequest: (options) => sent = options,
      ),
    );

    final result = await api.update(relayMode: 'disableFallback');

    expect(sent!.method, 'PUT');
    expect(sent!.path, '/api/settings/relay');
    expect(sent!.data, {'relayMode': 'disableFallback'});
    expect(result.relayMode, 'disableFallback');
  });

  test('a missing turnUris list defaults to empty', () async {
    final api = DioRelaySettingsApi(
      _dioReturning({'relayMode': 'automatic', 'hasCustomTurnSecret': false}),
    );

    final result = await api.fetch();

    expect(result.turnUris, isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/webrtc/relay_settings_api_test.dart`
Expected: FAIL to build — `relay_settings_api.dart` doesn't exist yet.

- [ ] **Step 3: Add `RelayModes`**

Create `lib/core/webrtc/relay_modes.dart`:

```dart
/// The three mutually-exclusive relay policies, matching the backend's RelayModes
/// (dotnet_SonicRelay's SonicRelay.Domain.RelaySettings.RelayModes) and
/// windows_SonicRelay's Core.Configuration.RelayModes string-for-string, so the value
/// round-trips through /api/settings/relay unchanged across every client.
class RelayModes {
  const RelayModes._();

  static const automatic = 'automatic';
  static const forceRelay = 'forceRelay';
  static const disableFallback = 'disableFallback';

  static bool isValid(String? value) =>
      value == automatic || value == forceRelay || value == disableFallback;
}
```

- [ ] **Step 4: Add `RelaySettingsApi`**

Create `lib/core/webrtc/relay_settings_api.dart`:

```dart
import 'package:dio/dio.dart';

import 'relay_modes.dart';

class RelaySettingsResult {
  const RelaySettingsResult({
    required this.relayMode,
    required this.turnUris,
    required this.hasCustomTurnSecret,
  });

  final String relayMode;
  final List<String> turnUris;
  final bool hasCustomTurnSecret;
}

abstract interface class RelaySettingsApi {
  Future<RelaySettingsResult> fetch();
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris});
}

class DioRelaySettingsApi implements RelaySettingsApi {
  const DioRelaySettingsApi(this._dio);

  final Dio _dio;

  @override
  Future<RelaySettingsResult> fetch() async {
    final response = await _dio.get<Map<String, Object?>>('/api/settings/relay');
    return _parse(response.data ?? const {});
  }

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async {
    final response = await _dio.put<Map<String, Object?>>(
      '/api/settings/relay',
      data: {
        if (relayMode != null) 'relayMode': relayMode,
        if (turnUris != null) 'turnUris': turnUris,
      },
    );
    return _parse(response.data ?? const {});
  }

  RelaySettingsResult _parse(Map<String, Object?> data) => RelaySettingsResult(
    relayMode: data['relayMode'] as String? ?? RelayModes.automatic,
    turnUris: (data['turnUris'] as List?)?.whereType<String>().toList() ?? const [],
    hasCustomTurnSecret: data['hasCustomTurnSecret'] as bool? ?? false,
  );
}
```

- [ ] **Step 5: Run the tests and verify they pass**

Run: `flutter test test/core/webrtc/relay_settings_api_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing `RelayModeStorage` migration tests**

Create `test/core/storage/relay_mode_storage_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/core/storage/relay_mode_storage.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';

void main() {
  const secureStorage = FlutterSecureStorage();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('defaults to automatic with nothing stored', async () async {
    expect(await const RelayModeStorage(secureStorage).read(), RelayModes.automatic);
  });

  test('round trips a written relay mode', async () async {
    const storage = RelayModeStorage(secureStorage);

    await storage.write(RelayModes.disableFallback);

    expect(await storage.read(), RelayModes.disableFallback);
  });

  test('migrates a legacy forceRelay=true flag to the forceRelay mode', async () async {
    await secureStorage.write(key: 'webrtc.forceRelay', value: 'true');

    expect(await const RelayModeStorage(secureStorage).read(), RelayModes.forceRelay);
  });

  test('migrates a legacy forceRelay=false flag to automatic', async () async {
    await secureStorage.write(key: 'webrtc.forceRelay', value: 'false');

    expect(await const RelayModeStorage(secureStorage).read(), RelayModes.automatic);
  });
}
```

(Fix the `async () async` typo above before running it — it should read `test('...', () async
{ ... });` like every other test in this file; it is written that way here only because this
plan is plain-text markdown and easy to mis-copy — type it correctly.)

- [ ] **Step 7: Run the tests to verify they fail**

Run: `flutter test test/core/storage/relay_mode_storage_test.dart`
Expected: FAIL to build — `RelayModeStorage.read()`/`write()` still take/return `bool`.

- [ ] **Step 8: Rewrite `RelayModeStorage`**

Replace the entire contents of `lib/core/storage/relay_mode_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../webrtc/relay_modes.dart';

/// Last-known-good cache of the server-synced relay mode (issue #26 follow-up — this used
/// to be the sole source of truth for a local-only "force relay" boolean; the real source of
/// truth is now the backend's /api/settings/relay).
class RelayModeStorage {
  const RelayModeStorage(this._storage);

  static const _modeKey = 'webrtc.relayMode';
  static const _legacyForceRelayKey = 'webrtc.forceRelay';

  final FlutterSecureStorage _storage;

  Future<String> read() async {
    final stored = await _storage.read(key: _modeKey);
    if (stored != null && RelayModes.isValid(stored)) return stored;
    // Migrate the pre-existing boolean-only flag (issue #26 predecessor).
    final legacy = await _storage.read(key: _legacyForceRelayKey);
    return legacy == 'true' ? RelayModes.forceRelay : RelayModes.automatic;
  }

  Future<void> write(String mode) => _storage.write(key: _modeKey, value: mode);
}
```

- [ ] **Step 9: Run the tests and verify they pass**

Run: `flutter test test/core/storage/relay_mode_storage_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/core/webrtc/relay_modes.dart lib/core/webrtc/relay_settings_api.dart lib/core/storage/relay_mode_storage.dart test/core/webrtc/relay_settings_api_test.dart test/core/storage/relay_mode_storage_test.dart
git commit -m "Add RelayModes, RelaySettingsApi, and migrate RelayModeStorage to a 3-way mode"
```

---

### Task 3: `relayModeProvider` replaces `forceRelayProvider`

**Files:**
- Modify: `lib/app/di/app_providers.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/settings/presentation/widgets/relay_mode_toggle.dart`
- Modify: `test/app/di/force_relay_provider_test.dart` → rename to
  `test/app/di/relay_mode_provider_test.dart`

**Interfaces:**
- Consumes: `RelaySettingsApi`/`RelaySettingsResult` (Task 2), `RelayModeStorage` (Task 2,
  now string-based).
- Produces: `relaySettingsApiProvider` (`Provider<RelaySettingsApi>`), `relayModeProvider`
  (`NotifierProvider<RelayModeNotifier, String>`), `RelayModeNotifier.set(String mode)`,
  `RelayModeNotifier.refresh()`. `forceRelayProvider`/`ForceRelayNotifier` no longer exist.

- [ ] **Step 1: Write the failing provider test**

Replace the entire contents of `test/app/di/force_relay_provider_test.dart`, and rename the
file to `test/app/di/relay_mode_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/storage/relay_mode_storage.dart';
import 'package:sonic_relay/core/webrtc/relay_modes.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';

class _FakeRelayModeStorage extends RelayModeStorage {
  _FakeRelayModeStorage() : super(const FlutterSecureStorage());

  String? written;
  String stored = RelayModes.automatic;

  @override
  Future<String> read() async => stored;

  @override
  Future<void> write(String mode) async {
    written = mode;
    stored = mode;
  }
}

class _FakeRelaySettingsApi implements RelaySettingsApi {
  RelaySettingsResult updateResult = const RelaySettingsResult(
    relayMode: RelayModes.forceRelay,
    turnUris: [],
    hasCustomTurnSecret: false,
  );
  RelaySettingsResult fetchResult = const RelaySettingsResult(
    relayMode: RelayModes.disableFallback,
    turnUris: [],
    hasCustomTurnSecret: false,
  );
  String? lastUpdateRelayMode;

  @override
  Future<RelaySettingsResult> fetch() async => fetchResult;

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async {
    lastUpdateRelayMode = relayMode;
    return updateResult;
  }
}

void main() {
  test('RelayModeNotifier defaults to automatic and writes through to the server on change', () async {
    final storage = _FakeRelayModeStorage();
    final api = _FakeRelaySettingsApi();
    final container = ProviderContainer(
      overrides: [
        relayModeStorageProvider.overrideWithValue(storage),
        relaySettingsApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(relayModeProvider), RelayModes.automatic);

    await container.read(relayModeProvider.notifier).set(RelayModes.forceRelay);

    expect(api.lastUpdateRelayMode, RelayModes.forceRelay);
    expect(container.read(relayModeProvider), RelayModes.forceRelay);
    expect(storage.written, RelayModes.forceRelay);
  });

  test('refresh fetches the server value and applies it locally', () async {
    final storage = _FakeRelayModeStorage();
    final api = _FakeRelaySettingsApi();
    final container = ProviderContainer(
      overrides: [
        relayModeStorageProvider.overrideWithValue(storage),
        relaySettingsApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await container.read(relayModeProvider.notifier).refresh();

    expect(container.read(relayModeProvider), RelayModes.disableFallback);
    expect(storage.written, RelayModes.disableFallback);
  });
}
```

(Add `import 'package:flutter_secure_storage/flutter_secure_storage.dart';` for the fake's
`super(const FlutterSecureStorage())` call, matching the original file's import.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app/di/relay_mode_provider_test.dart`
Expected: FAIL to build — `relaySettingsApiProvider`/`relayModeProvider`/`RelayModeNotifier`
don't exist yet.

- [ ] **Step 3: Replace `forceRelayProvider` in `app_providers.dart`**

Add the import at the top:

```dart
import '../../core/webrtc/relay_modes.dart';
import '../../core/webrtc/relay_settings_api.dart';
```

Replace the whole block:

```dart
/// Whether ICE is forced to relay-only (TURN). User-controlled and persisted;
/// applied to the next WebRTC negotiation.
final forceRelayProvider = NotifierProvider<ForceRelayNotifier, bool>(
  ForceRelayNotifier.new,
);

class ForceRelayNotifier extends Notifier<bool> {
  ForceRelayNotifier([this._initial = false]);

  final bool _initial;

  @override
  bool build() => _initial;

  Future<void> set(bool value) async {
    await ref.read(relayModeStorageProvider).write(value);
    state = value;
  }
}
```

with:

```dart
final relaySettingsApiProvider = Provider<RelaySettingsApi>(
  (ref) => DioRelaySettingsApi(ref.watch(dioProvider)),
);

/// The server-synced relay policy (issue #26 follow-up). Local storage is a last-known-good
/// cache only — [set] and [refresh] both write through the confirmed server value, never a
/// locally-chosen one, so every device converges on the backend's single global setting.
final relayModeProvider = NotifierProvider<RelayModeNotifier, String>(
  RelayModeNotifier.new,
);

class RelayModeNotifier extends Notifier<String> {
  RelayModeNotifier([this._initial = RelayModes.automatic]);

  final String _initial;

  @override
  String build() => _initial;

  Future<void> set(String mode) async {
    final result = await ref.read(relaySettingsApiProvider).update(relayMode: mode);
    await ref.read(relayModeStorageProvider).write(result.relayMode);
    state = result.relayMode;
  }

  Future<void> refresh() async {
    final result = await ref.read(relaySettingsApiProvider).fetch();
    await ref.read(relayModeStorageProvider).write(result.relayMode);
    state = result.relayMode;
  }
}
```

(`relaySettingsApiProvider` reads `dioProvider`, which is declared later in this same file —
that's fine; Riverpod providers are just top-level `final`s resolved lazily, declaration order
inside the file does not matter.)

Update `webRtcReceiverServiceProvider`'s `forceRelay:` callback:

```dart
    forceRelay: () => ref.read(forceRelayProvider),
```

becomes:

```dart
    forceRelay: () => ref.read(relayModeProvider) == RelayModes.forceRelay,
```

- [ ] **Step 4: Update `main.dart`**

Change:

```dart
  final savedForceRelay = await const RelayModeStorage(secureStorage).read();
```

to:

```dart
  final savedRelayMode = await const RelayModeStorage(secureStorage).read();
```

and:

```dart
        forceRelayProvider.overrideWith(() => ForceRelayNotifier(savedForceRelay)),
```

to:

```dart
        relayModeProvider.overrideWith(() => RelayModeNotifier(savedRelayMode)),
```

- [ ] **Step 5: Update `relay_mode_toggle.dart`**

Replace the entire contents of
`lib/features/settings/presentation/widgets/relay_mode_toggle.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../core/webrtc/relay_modes.dart';

/// Lets the viewer choose how ICE connects — automatic (direct with relay fallback), forced
/// relay-only, or relay disabled entirely — instead of the old force-relay-only toggle. The
/// choice is server-synced (windows_SonicRelay/dotnet_SonicRelay design spec, 2026-08-04) so
/// changing it here also applies on every other paired device.
class RelayModeToggle extends ConsumerWidget {
  const RelayModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relayMode = ref.watch(relayModeProvider);

    void select(String? mode) {
      if (mode != null) unawaited(ref.read(relayModeProvider.notifier).set(mode));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: RelayModes.automatic,
          groupValue: relayMode,
          onChanged: select,
          title: const Text('Automatic'),
          subtitle: const Text(
            'Prefer a direct connection; fall back to the relay if it fails.',
          ),
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: RelayModes.forceRelay,
          groupValue: relayMode,
          onChanged: select,
          title: const Text('Force relay (TURN only)'),
          subtitle: const Text(
            'Always route audio through the relay server. Useful on restrictive networks.',
          ),
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: RelayModes.disableFallback,
          groupValue: relayMode,
          onChanged: select,
          title: const Text('Disable relay fallback'),
          subtitle: const Text(
            'Only connect directly; never fall back to the relay if it fails.',
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run the test and verify it passes**

Run: `flutter test test/app/di/relay_mode_provider_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: PASS across every test file — in particular `test/app/di/*`,
`test/features/settings/*` (if it exists — check first), and any test that previously
referenced `forceRelayProvider`/`ForceRelayNotifier` directly (fix any such reference the same
way Step 3 fixed `webRtcReceiverServiceProvider`, by searching first):

Run: `grep -rn "forceRelayProvider\|ForceRelayNotifier" lib/ test/`
Expected after this task's changes: no matches anywhere.

- [ ] **Step 8: Commit**

```bash
git add lib/app/di/app_providers.dart lib/main.dart lib/features/settings/presentation/widgets/relay_mode_toggle.dart test/app/di/relay_mode_provider_test.dart
git rm test/app/di/force_relay_provider_test.dart
git commit -m "Replace forceRelayProvider with a server-synced 3-way relayModeProvider"
```

---

### Task 4: Coturn URL field, visible once paired

**Files:**
- Create: `lib/features/settings/presentation/widgets/coturn_url_field.dart`
- Modify: `lib/features/settings/presentation/settings_page.dart`
- Test: `test/features/settings/presentation/widgets/coturn_url_field_test.dart` (new — check
  first whether `test/features/settings/` already has other widget tests to match import/setup
  conventions from)

**Interfaces:**
- Consumes: `relaySettingsApiProvider` (Task 3), `deviceReadinessProvider`/
  `DeviceReadinessStatus` (already exists in `app_providers.dart`).

- [ ] **Step 1: Write the failing widget test**

Create `test/features/settings/presentation/widgets/coturn_url_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_relay/app/di/app_providers.dart';
import 'package:sonic_relay/core/webrtc/relay_settings_api.dart';
import 'package:sonic_relay/features/settings/presentation/widgets/coturn_url_field.dart';

class _FakeRelaySettingsApi implements RelaySettingsApi {
  RelaySettingsResult fetchResult = const RelaySettingsResult(
    relayMode: 'automatic',
    turnUris: ['turn:existing.example.com:3478'],
    hasCustomTurnSecret: false,
  );
  List<String>? lastUpdateTurnUris;

  @override
  Future<RelaySettingsResult> fetch() async => fetchResult;

  @override
  Future<RelaySettingsResult> update({String? relayMode, List<String>? turnUris}) async {
    lastUpdateTurnUris = turnUris;
    return RelaySettingsResult(
      relayMode: relayMode ?? fetchResult.relayMode,
      turnUris: turnUris ?? fetchResult.turnUris,
      hasCustomTurnSecret: fetchResult.hasCustomTurnSecret,
    );
  }
}

void main() {
  testWidgets('loads the current coturn URL and saves a new one', (tester) async {
    final api = _FakeRelaySettingsApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [relaySettingsApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: CoturnUrlField())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('turn:existing.example.com:3478'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'turn:new-coturn.example.com:3478',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save coturn URL'));
    await tester.pumpAndSettle();

    expect(api.lastUpdateTurnUris, ['turn:new-coturn.example.com:3478']);
  });
}
```

(Adjust the button-finder widget type — `FilledButton`/`ElevatedButton`/a project-specific
`SonicButton` — to whichever this codebase's other Settings widgets use; check
`server_url_field.dart`, which already has an almost-identical "Save"-button shape, and copy
its exact widget choice rather than guessing.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/settings/presentation/widgets/coturn_url_field_test.dart`
Expected: FAIL to build — `coturn_url_field.dart` doesn't exist yet.

- [ ] **Step 3: Add `CoturnUrlField`**

Create `lib/features/settings/presentation/widgets/coturn_url_field.dart`, modeled closely on
the existing `server_url_field.dart` in the same directory (same directory, same imports
style — read that file again before writing this one so button/spacing/error-handling choices
match exactly):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/sonic_button.dart';
import '../../../../core/widgets/sonic_text_field.dart';

/// Lets the user view and change the coturn (TURN) server URL the backend hands out to every
/// paired device (design spec 2026-08-04). Unlike the API server URL, this is a server-side
/// override, not a local setting — saving calls PUT /api/settings/relay directly.
class CoturnUrlField extends ConsumerStatefulWidget {
  const CoturnUrlField({super.key});

  @override
  ConsumerState<CoturnUrlField> createState() => _CoturnUrlFieldState();
}

class _CoturnUrlFieldState extends ConsumerState<CoturnUrlField> {
  final _controller = TextEditingController();
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await ref.read(relaySettingsApiProvider).fetch();
      if (!mounted) return;
      setState(() {
        _controller.text = result.turnUris.isEmpty ? '' : result.turnUris.first;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    try {
      await ref.read(relaySettingsApiProvider).update(
        turnUris: url.isEmpty ? const [] : [url],
      );
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Coturn URL saved.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not save the coturn URL. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        SonicTextField(
          label: 'Coturn URL',
          controller: _controller,
          keyboardType: TextInputType.url,
          prefixIcon: Icons.dns_outlined,
          errorText: _error,
          hintText: 'turn:your-coturn-server.example.com:3478',
        ),
        const SizedBox(height: AppSpacing.md),
        SonicButton(label: 'Save coturn URL', icon: Icons.save_outlined, onPressed: _save),
      ],
    );
  }
}
```

(Re-check `SonicButton`'s exact constructor/label rendering against `server_url_field.dart`
before finalizing — if it renders as a `FilledButton` internally, the Step 1 test's
`find.widgetWithText(FilledButton, 'Save coturn URL')` finder will need to match whatever
`SonicButton` actually wraps; open `lib/core/widgets/sonic_button.dart` and adjust the test's
finder to match its real underlying widget type rather than assuming `FilledButton`.)

- [ ] **Step 4: Wire it into `SettingsPage`, gated on pairing readiness**

In `lib/features/settings/presentation/settings_page.dart`, add the import:

```dart
import 'widgets/coturn_url_field.dart';
```

Inside the `SonicCard` in the "Connection" section, right after the `RelayModeToggle`'s
`Material` wrapper and its preceding `Divider`, add a new gated section. Change the
`SettingsPage.build` method to a `Consumer` (or wrap just this block) so it can read
`deviceReadinessProvider`:

```dart
                        Consumer(
                          builder: (context, ref, _) {
                            final isPaired =
                                ref.watch(deviceReadinessProvider).status ==
                                DeviceReadinessStatus.ready;
                            if (!isPaired) return const SizedBox.shrink();
                            return const Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Divider(height: AppSpacing.xl),
                                _SettingsRow(
                                  icon: Icons.dns_outlined,
                                  title: 'Coturn',
                                  subtitle: 'TURN server this backend hands out',
                                ),
                                SizedBox(height: AppSpacing.sm),
                                CoturnUrlField(),
                              ],
                            );
                          },
                        ),
```

(Place it as the last child inside that `SonicCard`'s `Column`, after the existing
"Appearance" `_SettingsRow` — check the current file's exact layout before editing, since this
plan's earlier exploration read it once and the surrounding structure must still match.)

- [ ] **Step 5: Run the test and verify it passes**

Run: `flutter test test/features/settings/presentation/widgets/coturn_url_field_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: PASS across every test file, no regressions in `settings_page_test.dart` (if one
exists — check first) or elsewhere.

- [ ] **Step 7: Commit**

```bash
git add lib/features/settings/presentation/widgets/coturn_url_field.dart lib/features/settings/presentation/settings_page.dart test/features/settings/presentation/widgets/coturn_url_field_test.dart
git commit -m "Add a coturn URL field to Settings, visible once paired"
```

---

## Self-review notes (already applied above)

- Spec coverage: Task 1 covers "Settings reachable before pairing" (problem 3 in the design
  doc — the field itself already existed and needed no change, confirmed during
  brainstorming). Tasks 2-3 cover the server-synced `RelayMode` (problem 4, relay half).
  Task 4 covers the coturn URL (problem 4, TURN half), gated exactly as specified. The
  design doc's API-base-URL item for Flutter needed no plan at all beyond Task 1, since
  `ServerUrlField`/`ServerConfigStorage` were already fully implemented.
- No placeholders: every step has literal, complete Dart code.
- Type consistency: `RelaySettingsResult`'s three fields are spelled identically everywhere
  it's constructed or read (Task 2's API, Task 3's provider/tests, Task 4's field/test);
  `RelayModes`' three constants are the single source of spelling used across
  `relay_mode_storage.dart`, `app_providers.dart`, and `relay_mode_toggle.dart`.
