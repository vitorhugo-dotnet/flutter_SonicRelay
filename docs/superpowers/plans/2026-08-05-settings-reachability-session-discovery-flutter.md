# Settings Reachability & Session Discovery — Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Settings reachable before pairing, stop rejecting valid session codes (and explain a broken pairing when it happens), move relay/coturn settings to local per-device preferences, and let a paired viewer discover and join an open session without typing a code.

**Architecture:** Four independent slices. Task 1 is a redirect fix in `app_router.dart`. Task 2 aligns code validation with the backend and maps the new `403 not_paired`. Task 3 deletes `RelaySettingsApi` and turns the coturn field into a local override applied in `IceServersRepository`. Task 4 adds discovery on top of the backend endpoints delivered in the backend plan.

**Tech Stack:** Flutter, Riverpod (`NotifierProvider`), go_router, Dio, `flutter_secure_storage`, `flutter_test`.

## Global Constraints

- Backend contract, delivered by the dotnet plan and depended on here:
  - `POST /api/sessions/join` → `404 { code: "invalid_code" }` or `403 { code: "not_paired" }`
  - `GET /api/sessions/discoverable` → `200` array of `{ sessionId, publisherDeviceId, publisherDeviceName, status, viewerCount, maxViewers, createdAt }`
  - `POST /api/sessions/{sessionId}/join` → `200` (same body as the code path), `403 not_paired`, `404 invalid_code`, `409` viewer limit
- A session code is exactly six characters, `[A-Z0-9]`. The backend rejects anything else.
- `RelayModes` values stay the literals `automatic`, `forceRelay`, `disableFallback`, string-identical to the other two repos.
- The relay/coturn preference is per-device and local. Nothing may call `/api/settings/relay` after Task 3.
- The coturn field is never pre-filled with the backend's value. Blank means "use whatever the server sends".
- Run tests with: `flutter test`
- Run the analyzer with: `flutter analyze`
- Commit after every task.

---

### Task 1: Reach Settings before pairing

`deviceIdentityRedirect` returns `/pair` for every location while the readiness
status is `pairingRequired`, so the Settings action on the pairing page
(`pairing_page.dart:39`) is redirected straight back. A wrong backend URL
therefore cannot be corrected: you cannot reach Settings without pairing, and
you cannot pair against the wrong URL.

**Files:**
- Modify: `lib/app/router/app_router.dart:24-26`
- Test: `test/app/app_router_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `deviceIdentityRedirect(DeviceReadinessState, String)` keeps its
  signature; only the `pairingRequired` branch changes.

- [ ] **Step 1: Write the failing test**

Append to `test/app/app_router_test.dart`:

```dart
test('unpaired device can still reach settings', () {
  expect(
    deviceIdentityRedirect(
      const DeviceReadinessState.pairingRequired(),
      '/settings',
    ),
    isNull,
  );
});

test('unpaired device is still redirected away from other pages', () {
  expect(
    deviceIdentityRedirect(
      const DeviceReadinessState.pairingRequired(),
      '/listener',
    ),
    '/pair',
  );
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app/app_router_test.dart`
Expected: FAIL — `Expected: null, Actual: '/pair'`.

- [ ] **Step 3: Allow settings while pairing is required**

In `lib/app/router/app_router.dart`, change the `pairingRequired` branch:

```dart
    case DeviceReadinessStatus.pairingRequired:
      // Settings must stay reachable here: it holds the server URL field, and a device
      // pointed at the wrong backend can never pair, so redirecting Settings back to /pair
      // left no way to fix it from inside the app. The restoring/deviceSetup branches are
      // deliberately unchanged — before a device credential exists there is no authenticated
      // client for Settings to talk to, and _DeviceSetupPage already owns that retry path.
      return location == '/pair' || location == '/settings' ? null : '/pair';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/app/app_router_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/app/router/app_router.dart test/app/app_router_test.dart
git commit -m "Let an unpaired device reach Settings

The pairing page has had a Settings action since the last change, but the
global redirect sent it straight back to /pair. A device pointed at the wrong
backend URL could not pair and could not reach the field that would fix it."
```

---

### Task 2: Accept the codes the backend actually issues

The backend requires exactly six alphanumerics. The viewer validates
`^[A-Z0-9-]{4,12}$` and hints `SR-4F8K` — a format the server rejects outright.
Separators are not stripped, so a pasted code fails too. And a `403 not_paired`
must not be reported as a bad code.

**Files:**
- Modify: `lib/features/sessions/presentation/join_session_view_model.dart:35,45-52`
- Modify: `lib/features/sessions/presentation/widgets/session_code_input.dart`
- Modify: `lib/features/sessions/data/sessions_repository.dart`
- Test: `test/features/sessions/presentation/join_session_view_model_test.dart`
- Test: `test/features/sessions/data/sessions_repository_test.dart`

**Interfaces:**
- Consumes: the backend's `403 not_paired` body.
- Produces: `SessionsFailureKind.notPaired`, consumed by Task 4's tap-to-join
  path as well.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/sessions/presentation/join_session_view_model_test.dart`:

```dart
test('normalises separators and casing into a six-character code', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final viewModel = container.read(joinSessionViewModelProvider.notifier);

  viewModel.updateCode(' sr-4f8k ');

  expect(container.read(joinSessionViewModelProvider).code, 'SR4F8K');
});

test('rejects a code that is not exactly six characters', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final viewModel = container.read(joinSessionViewModelProvider.notifier);

  viewModel.updateCode('ABC');
  await viewModel.join();

  expect(
    container.read(joinSessionViewModelProvider).validationMessage,
    isNotNull,
  );
});
```

Append to `test/features/sessions/data/sessions_repository_test.dart`, matching
the `DioException` construction the neighbouring tests in that file already use:

```dart
test('maps 403 not_paired to a pairing failure, not an invalid code', () async {
  final repository = SessionsRepository(
    api: _ThrowingSessionsApi(
      DioException(
        requestOptions: RequestOptions(path: '/api/sessions/join'),
        response: Response<Map<String, Object?>>(
          requestOptions: RequestOptions(path: '/api/sessions/join'),
          statusCode: 403,
          data: const {'code': 'not_paired', 'error': 'not paired'},
        ),
      ),
    ),
    config: AppConfig.fromServerUrl('https://example.test'),
  );

  await expectLater(
    repository.join('FE237F'),
    throwsA(
      isA<SessionsFailure>().having(
        (failure) => failure.kind,
        'kind',
        SessionsFailureKind.notPaired,
      ),
    ),
  );
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/sessions`
Expected: FAIL — `SessionsFailureKind.notPaired` is undefined and `'sr-4f8k'`
normalises to `SR-4F8K`.

- [ ] **Step 3: Fix validation and normalisation**

In `lib/features/sessions/presentation/join_session_view_model.dart`, change
the pattern and the normaliser:

```dart
  // Exactly what the backend accepts (SessionEndpoints.JoinAsync): six ASCII alphanumerics.
  // The old 4-12 pattern with hyphens let codes through that the server always rejected,
  // which surfaced to the user as a useless "invalid code".
  static final _validCode = RegExp(r'^[A-Z0-9]{6}$');
```

```dart
  void updateCode(String value) {
    // Strip whitespace and hyphens anywhere in the string, not just at the ends, so a code
    // that was pasted or read aloud with separators still normalises to what the server wants.
    state = JoinSessionState(
      code: value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase(),
    );
  }
```

In `lib/features/sessions/presentation/widgets/session_code_input.dart`, cap
the length and fix the misleading hint.

The formatter must strip separators, not just upper-case. Flutter appends its
`LengthLimitingTextInputFormatter` AFTER the widget's own `inputFormatters`
(`packages/flutter/lib/src/material/text_field.dart:229-230, 1553-1556`), so a
`maxLength` of 6 truncates the RAW text before `onChanged` fires. With
stripping done only in `updateCode`, a pasted `SR-4F8K` is truncated to
`SR-4F8` first and then stripped to `SR4F8` — five characters, rejected. That
reintroduces the very bug this task exists to fix. Replacing
`_UpperCaseTextFormatter` with one that upper-cases AND drops anything outside
`[A-Z0-9]` makes the length limiter measure already-clean text:

```dart
      maxLength: 6,
      inputFormatters: [_SessionCodeFormatter()],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Session code',
        hintText: 'FE237F',
        counterText: '',
        prefixIcon: const Icon(Icons.tag_rounded),
        errorText: errorText,
      ),
```

- [ ] **Step 4: Map the new failure**

In `lib/features/sessions/data/sessions_repository.dart`, add the kind to the
enum:

```dart
enum SessionsFailureKind {
  missingDevice,
  invalidCode,
  expiredCode,
  maxViewers,
  notPaired,
  unauthorized,
  manualRetry,
  network,
  invalidResponse,
}
```

and branch on it in `_mapDioFailure`, **before** the existing `401 || 403`
check, which would otherwise swallow it:

```dart
    if (status == 403 && text.contains('not_paired')) {
      return const SessionsFailure(
        SessionsFailureKind.notPaired,
        'This device is no longer paired with that publisher. Pair again from the '
        'pairing screen, then retry.',
      );
    }
    if (status == 401 || status == 403) {
```

Keep the stripping in `updateCode` as well — the view model is called directly
by tests and must not assume the widget already sanitised its input. Add a
widget-level test driving the real pipeline: enter `SR-4F8K` into
`SessionCodeInput` and assert `onChanged` receives `SR4F8K`. Every other test
bypasses that seam.

In `join_session_view_model.dart`, `notPaired` must not be retryable — retrying
cannot fix it — so leave it out of the `retryable` expression, which already
lists only the recoverable kinds.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/sessions && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/sessions test/features/sessions
git commit -m "Accept the six-character codes the backend actually issues

The viewer validated 4-12 characters with hyphens and hinted SR-4F8K, a shape
the server rejects outright, and pasted codes kept their separators. A 403
not_paired is now reported as a pairing problem instead of being folded into
the generic invalid-code message, which is what made a dead pairing look like
a typo."
```

---

### Task 3: Local relay preferences and a local coturn override

**Files:**
- Delete: `lib/core/webrtc/relay_settings_api.dart`
- Delete: `test/core/webrtc/relay_settings_api_test.dart` (if present)
- Create: `lib/core/storage/coturn_override_storage.dart`
- Modify: `lib/app/di/app_providers.dart` (`relaySettingsApiProvider`, `RelayModeNotifier`, new `coturnOverrideProvider`)
- Modify: `lib/core/webrtc/ice_servers_repository.dart`
- Modify: `lib/features/settings/presentation/widgets/coturn_url_field.dart`
- Modify: `lib/features/settings/presentation/settings_page.dart`
- Test: `test/core/webrtc/ice_servers_repository_test.dart`
- Test: `test/features/settings/presentation/widgets/coturn_url_field_test.dart`

**Interfaces:**
- Consumes: nothing from Tasks 1-2.
- Produces: `coturnOverrideProvider` (`NotifierProvider<CoturnOverrideNotifier, String?>`),
  `CoturnOverrideNotifier.set(String?)`, and an `IceServersRepository` whose
  constructor takes `relayMode: String Function()` and
  `coturnOverride: String? Function()`.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/webrtc/ice_servers_repository_test.dart`:

```dart
test('a coturn override replaces the turn url and keeps the credentials', () async {
  final repository = IceServersRepository(
    api: _StubIceServersApi(
      const RtcIceServerConfig([
        RtcIceServer(urls: ['stun:backend.example.com:3478']),
        RtcIceServer(
          urls: ['turn:backend.example.com:3478?transport=udp'],
          username: '1700000000:device',
          credential: 'signed-credential',
        ),
      ]),
    ),
    relayMode: () => RelayModes.automatic,
    coturnOverride: () => 'turn:my-relay.example.com:3478?transport=udp',
  );

  final config = await repository.resolve();

  final turn = config.iceServers.firstWhere((s) => s.urls.first.startsWith('turn:'));
  expect(turn.urls.single, 'turn:my-relay.example.com:3478?transport=udp');
  expect(turn.username, '1700000000:device');
  expect(turn.credential, 'signed-credential');
  expect(config.iceServers.any((s) => s.urls.first.startsWith('stun:')), isTrue);
});

test('no override passes the backend list through untouched', () async {
  final repository = IceServersRepository(
    api: _StubIceServersApi(
      const RtcIceServerConfig([
        RtcIceServer(
          urls: ['turn:backend.example.com:3478?transport=udp'],
          username: 'u',
          credential: 'c',
        ),
      ]),
    ),
    relayMode: () => RelayModes.automatic,
    coturnOverride: () => null,
  );

  final config = await repository.resolve();

  expect(config.iceServers.single.urls.single, 'turn:backend.example.com:3478?transport=udp');
});

test('disableFallback drops turn entries client side', () async {
  final repository = IceServersRepository(
    api: _StubIceServersApi(
      const RtcIceServerConfig([
        RtcIceServer(urls: ['stun:backend.example.com:3478']),
        RtcIceServer(
          urls: ['turn:backend.example.com:3478?transport=udp'],
          username: 'u',
          credential: 'c',
        ),
      ]),
    ),
    relayMode: () => RelayModes.disableFallback,
    coturnOverride: () => null,
  );

  final config = await repository.resolve();

  expect(config.iceServers.any((s) => s.urls.first.startsWith('turn:')), isFalse);
  expect(config.iceServers, hasLength(1));
});
```

Write `_StubIceServersApi` as a minimal `IceServersApi` returning an
`IceServersResult` with the supplied config and an `expiresAt` an hour out.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/webrtc/ice_servers_repository_test.dart`
Expected: FAIL — `IceServersRepository` has no `relayMode` or `coturnOverride`
parameter.

- [ ] **Step 3: Add the local override store**

Create `lib/core/storage/coturn_override_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A user-supplied TURN URL that replaces the one the backend hands out, or null to use the
/// backend's. Deliberately never pre-filled with the backend's value: the deployment's relay
/// host is not disclosed through this UI, and blank means "use whatever the server sends".
///
/// The TURN credential is signed by the backend as
/// HMAC-SHA1(TURN_STATIC_AUTH_SECRET, "<expiry>:<deviceId>") and this override reuses it, so
/// it only authenticates against a coturn sharing that same static secret — another host or
/// port of the same relay deployment, not a third-party TURN server.
class CoturnOverrideStorage {
  const CoturnOverrideStorage(this._storage);

  static const _key = 'webrtc.coturnUrlOverride';

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    final stored = await _storage.read(key: _key);
    if (stored == null || stored.trim().isEmpty) return null;
    return stored;
  }

  Future<void> write(String? url) async {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _storage.delete(key: _key);
      return;
    }
    await _storage.write(key: _key, value: normalized);
  }
}
```

- [ ] **Step 4: Apply the preferences in the repository**

In `lib/core/webrtc/ice_servers_repository.dart`, add the two callbacks to the
constructor and apply them to every successful fetch:

```dart
  IceServersRepository({
    required IceServersApi api,
    required String Function() relayMode,
    required String? Function() coturnOverride,
    DateTime Function()? now,
    bool? allowGoogleStunDevFallback,
  }) : _api = api,
       _relayMode = relayMode,
       _coturnOverride = coturnOverride,
       _now = now ?? DateTime.now,
       _allowGoogleStunDevFallback =
           allowGoogleStunDevFallback ?? kDebugMode;

  final String Function() _relayMode;
  final String? Function() _coturnOverride;
```

In `resolve`, replace `_cached = result.config;` with:

```dart
      _cached = _applyPreferences(result.config);
      return _cached!;
```

and add:

```dart
  /// Applies this device's local relay preferences to the backend's list. `disableFallback`
  /// is enforced here rather than server-side because the preference is per-device: a backend
  /// that withheld TURN would impose one device's choice on every other device it serves.
  /// The override swaps only the TURN urls — STUN entries carry no credential, and the
  /// server-issued username/credential are preserved because they are what authenticates.
  RtcIceServerConfig _applyPreferences(RtcIceServerConfig config) {
    final override = _coturnOverride();
    final disableFallback = _relayMode() == RelayModes.disableFallback;
    final servers = <RtcIceServer>[];
    for (final server in config.iceServers) {
      final isTurn = server.urls.first.toLowerCase().startsWith('turn:') ||
          server.urls.first.toLowerCase().startsWith('turns:');
      if (isTurn && disableFallback) continue;
      servers.add(
        isTurn && override != null
            ? RtcIceServer(
                urls: [override],
                username: server.username,
                credential: server.credential,
              )
            : server,
      );
    }
    // forceRelay is preserved rather than defaulted: it is a separate field on the config
    // (applied as iceTransportPolicy) that the receiver service sets, not part of the list.
    return RtcIceServerConfig(servers, forceRelay: config.forceRelay);
  }
```

Import `relay_modes.dart`. Note the list field is named `iceServers` (not
`servers`) and the constructor is positional:
`RtcIceServerConfig(this.iceServers, {this.forceRelay = false})`.

- [ ] **Step 5: Rewire the providers**

In `lib/app/di/app_providers.dart`, delete `relaySettingsApiProvider` and its
import, and make `RelayModeNotifier` local-only:

```dart
/// This device's relay policy. Local by design: it used to sync through a backend row that
/// was global to the whole deployment, so one device changing it changed the relay for every
/// other device the backend served.
final relayModeProvider = NotifierProvider<RelayModeNotifier, String>(
  RelayModeNotifier.new,
);

class RelayModeNotifier extends Notifier<String> {
  RelayModeNotifier([this._initial = RelayModes.automatic]);

  final String _initial;

  @override
  String build() => _initial;

  Future<void> set(String mode) async {
    await ref.read(relayModeStorageProvider).write(mode);
    state = mode;
  }
}
```

Add the override provider:

```dart
final coturnOverrideStorageProvider = Provider<CoturnOverrideStorage>(
  (ref) => CoturnOverrideStorage(ref.watch(secureStorageProvider)),
);

final coturnOverrideProvider =
    NotifierProvider<CoturnOverrideNotifier, String?>(
      CoturnOverrideNotifier.new,
    );

class CoturnOverrideNotifier extends Notifier<String?> {
  CoturnOverrideNotifier([this._initial]);

  final String? _initial;

  @override
  String? build() => _initial;

  Future<void> set(String? url) async {
    final normalized = (url == null || url.trim().isEmpty) ? null : url.trim();
    await ref.read(coturnOverrideStorageProvider).write(normalized);
    state = normalized;
  }
}
```

Pass both into the repository:

```dart
final iceServersRepositoryProvider = Provider<IceServersRepository>(
  (ref) => IceServersRepository(
    api: ref.watch(iceServersApiProvider),
    relayMode: () => ref.read(relayModeProvider),
    coturnOverride: () => ref.read(coturnOverrideProvider),
  ),
);
```

Delete `lib/core/webrtc/relay_settings_api.dart` and its test file. In
`main.dart`, seed `relayModeProvider` and `coturnOverrideProvider` overrides
from storage alongside the existing `serverUrlProvider` seeding — follow the
pattern already there for the persisted server URL.

- [ ] **Step 6: Rewrite the coturn field**

Replace the body of
`lib/features/settings/presentation/widgets/coturn_url_field.dart` so it reads
and writes `coturnOverrideProvider` instead of the API. The `_turnUrlPattern`
validator and the `SonicTextField`/`SonicButton` layout stay; delete `_load`,
`_loaded`, `_loadFailed` and the retry branch entirely — there is nothing to
fetch. Initialise the controller from `ref.read(coturnOverrideProvider) ?? ''`
in `initState`, and change `_save` to:

```dart
  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isNotEmpty && !_isValid(url)) {
      setState(() {
        _error = 'Enter a valid TURN URL, e.g. turn:your-coturn-server.example.com:3478';
      });
      return;
    }
    await ref.read(coturnOverrideProvider.notifier).set(url);
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(url.isEmpty ? 'Using the server relay.' : 'Coturn URL saved.')),
      );
  }
```

Update the class doc comment: it currently says the field is a server-side
override applied to every paired device, which is the behaviour being removed.

In `lib/features/settings/presentation/settings_page.dart`, replace both
occurrences of `'Applies to every device paired with this backend.'` with
`'Applies to this device only.'`, and in `_ConnectionSection` delete
`initState`, the `_refreshRelayMode` method and the `WidgetsBinding` callback —
there is no server value to refresh. It can become a `ConsumerWidget` again.
Drop the `dart:async` import if nothing else in the file uses it.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: PASS. Tests in
`test/features/settings/presentation/widgets/coturn_url_field_test.dart` that
assert the fetch-on-mount, load-failure and save-through-API behaviour must be
replaced with local-override equivalents — they cover behaviour that no longer
exists.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Move relay mode and the coturn override to local preferences

The backend row these synced through was global to the whole deployment, so
one device editing the coturn URL changed the relay for every other device.
Both are per-device now, and the field starts blank and never shows the
backend's own value. disableFallback becomes a client-side filter, which is
what a per-device preference has to be."
```

---

### Task 4: Discover and join a paired publisher's session

**Files:**
- Create: `lib/features/sessions/data/dto/discoverable_session.dart`
- Create: `lib/features/sessions/presentation/widgets/discovered_sessions_list.dart`
- Modify: `lib/features/sessions/data/sessions_api.dart`
- Modify: `lib/features/sessions/data/sessions_repository.dart`
- Modify: `lib/app/di/app_providers.dart` (new `discoverableSessionsProvider`)
- Modify: `lib/features/sessions/presentation/join_session_view_model.dart`
- Modify: `lib/features/sessions/presentation/join_session_page.dart`
- Test: `test/features/sessions/data/sessions_repository_test.dart`
- Test: `test/features/sessions/presentation/join_session_page_test.dart`

**Interfaces:**
- Consumes: `SessionsFailureKind.notPaired` from Task 2; the backend's
  `/api/sessions/discoverable` and `/api/sessions/{id}/join`.
- Produces: `DiscoverableSession` (`sessionId`, `publisherDeviceName`, `status`,
  `viewerCount`, `maxViewers`), `SessionsRepository.discover()`,
  `SessionsRepository.joinById(String sessionId)`, and
  `JoinSessionViewModel.joinDiscovered(DiscoverableSession)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/sessions/data/sessions_repository_test.dart`:

```dart
test('discover maps the backend payload', () async {
  final repository = SessionsRepository(
    api: _StubSessionsApi(discoverable: const [
      DiscoverableSession(
        sessionId: '11111111-1111-1111-1111-111111111111',
        publisherDeviceName: 'VITOR-DESKTOP',
        status: 'waiting',
        viewerCount: 0,
        maxViewers: 3,
      ),
    ]),
    config: AppConfig.fromServerUrl('https://example.test'),
  );

  final sessions = await repository.discover();

  expect(sessions.single.publisherDeviceName, 'VITOR-DESKTOP');
  expect(sessions.single.viewerCount, 0);
});

test('discover returns an empty list rather than throwing on failure', () async {
  final repository = SessionsRepository(
    api: _ThrowingSessionsApi(
      DioException(requestOptions: RequestOptions(path: '/api/sessions/discoverable')),
    ),
    config: AppConfig.fromServerUrl('https://example.test'),
  );

  expect(await repository.discover(), isEmpty);
});
```

Append to `test/features/sessions/presentation/join_session_page_test.dart`,
following the `ProviderScope` override style already used in that file:

```dart
testWidgets('lists discovered sessions below the code field', (tester) async {
  await tester.pumpWidget(_wrap(discoverable: const [
    DiscoverableSession(
      sessionId: '11111111-1111-1111-1111-111111111111',
      publisherDeviceName: 'VITOR-DESKTOP',
      status: 'waiting',
      viewerCount: 0,
      maxViewers: 3,
    ),
  ]));
  await tester.pumpAndSettle();

  expect(find.text('VITOR-DESKTOP'), findsOneWidget);
});

testWidgets('renders nothing extra when no session is discovered', (tester) async {
  await tester.pumpWidget(_wrap(discoverable: const []));
  await tester.pumpAndSettle();

  expect(find.byType(DiscoveredSessionsList), findsNothing);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/sessions`
Expected: FAIL — `DiscoverableSession`, `discover` and `DiscoveredSessionsList`
are undefined.

- [ ] **Step 3: Add the DTO and the API calls**

Create `lib/features/sessions/data/dto/discoverable_session.dart`:

```dart
/// A session of a publisher this device is actively paired with, offered for a code-free
/// join. The backend deliberately never includes the join code here — it is a separate
/// short-lived secret, and discovery must not become a way to read it.
class DiscoverableSession {
  const DiscoverableSession({
    required this.sessionId,
    required this.publisherDeviceName,
    required this.status,
    required this.viewerCount,
    required this.maxViewers,
  });

  factory DiscoverableSession.fromJson(Map<String, Object?> json) =>
      DiscoverableSession(
        sessionId: json['sessionId'] as String? ?? '',
        publisherDeviceName: json['publisherDeviceName'] as String? ?? '',
        status: json['status'] as String? ?? 'waiting',
        viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
        maxViewers: (json['maxViewers'] as num?)?.toInt() ?? 0,
      );

  final String sessionId;
  final String publisherDeviceName;
  final String status;
  final int viewerCount;
  final int maxViewers;

  bool get isFull => maxViewers > 0 && viewerCount >= maxViewers;
}
```

In `lib/features/sessions/data/sessions_api.dart`, add to the interface and the
Dio implementation:

```dart
  Future<List<DiscoverableSession>> discover();
  Future<JoinSessionResponse> joinById(String sessionId);
```

```dart
  @override
  Future<List<DiscoverableSession>> discover() async {
    final response = await _dio.get<List<Object?>>('/api/sessions/discoverable');
    return (response.data ?? const [])
        .whereType<Map>()
        .map((entry) => DiscoverableSession.fromJson(Map<String, Object?>.from(entry)))
        .toList();
  }

  @override
  Future<JoinSessionResponse> joinById(String sessionId) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/sessions/$sessionId/join',
    );
    return JoinSessionResponse.fromJson(response.data!);
  }
```

In `lib/features/sessions/data/sessions_repository.dart`:

```dart
  /// Best-effort: discovery is an accelerator on top of manual code entry, so a failure
  /// returns an empty list rather than surfacing an error over a code field that still works.
  Future<List<DiscoverableSession>> discover() async {
    try {
      return await _api.discover();
    } catch (_) {
      return const [];
    }
  }

  Future<StreamSession> joinById(String sessionId) async {
    try {
      final response = await _api.joinById(sessionId);
      final session = response.toDomain(_config.signalingUri);
      _currentSession = session;
      return session;
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    } on FormatException {
      throw const SessionsFailure(
        SessionsFailureKind.invalidResponse,
        'The server returned invalid session data. Please retry.',
      );
    }
  }
```

- [ ] **Step 4: Add the provider and the view-model entry point**

In `lib/app/di/app_providers.dart`:

```dart
/// Polls for sessions of paired publishers while the join page is mounted. `autoDispose` so
/// the poll stops with the page, and a short period because the publisher can start a session
/// at any moment and this is the only signal the viewer gets.
final discoverableSessionsProvider =
    StreamProvider.autoDispose<List<DiscoverableSession>>((ref) async* {
  final repository = ref.watch(sessionsRepositoryProvider);
  while (true) {
    yield await repository.discover();
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});
```

In `join_session_view_model.dart`, add the tap-to-join path, reusing the same
state transitions `join()` uses:

```dart
  Future<void> joinDiscovered(DiscoverableSession session) async {
    state = JoinSessionState(code: state.code, status: JoinSessionStatus.joining);
    try {
      final joined = await _repository.joinById(session.sessionId);
      state = JoinSessionState(
        code: state.code,
        status: JoinSessionStatus.joined,
        session: joined,
      );
    } on SessionsFailure catch (error) {
      state = JoinSessionState(
        code: state.code,
        status: JoinSessionStatus.failed,
        errorMessage: error.message,
        retryable: error.kind == SessionsFailureKind.network,
      );
    }
  }
```

- [ ] **Step 5: Render the list**

Create `lib/features/sessions/presentation/widgets/discovered_sessions_list.dart`
as a `ConsumerWidget` that watches `discoverableSessionsProvider` and returns
`const SizedBox.shrink()` for loading, error, and empty results — an idle
publisher is the normal case, and a permanent "no sessions" panel would add
noise to the primary manual-entry flow. For a non-empty list render a
`SonicCard` with one `ListTile` per session: `publisherDeviceName` as the
title, `'$status · $viewerCount/$maxViewers viewers'` as the subtitle, and
`onTap` calling `joinDiscovered`, disabled when `session.isFull`.

In `join_session_page.dart`, insert it directly below the `SonicCard` holding
the code field and above the `state.errorMessage` block:

```dart
                  const SizedBox(height: AppSpacing.md),
                  const DiscoveredSessionsList(),
```

The existing `ref.listen` on `joinSessionViewModelProvider` already navigates to
`/session/waiting` on the `joined` transition, so the tap path needs no
navigation of its own.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Discover and join a paired publisher's session without a code

A paired viewer had no way to see that its publisher was broadcasting; the
only path in was reading a six-character code off the desktop screen. The
join page now lists sessions of actively paired publishers and joins them on
tap, with the code field unchanged as the manual fallback. The list is hidden
when empty and silent on failure, since the code path still works."
```

---

## Verification

```bash
flutter test
flutter analyze
grep -rn "relaySettingsApi\|settings/relay\|SR-4F8K\|every device paired" lib/ test/
```

Expected: all tests pass, no analyzer issues, and the grep returns no output.

Then verify against a live backend and desktop: pair the phone, confirm
Settings opens from the pairing screen before pairing completes, create a
session on the desktop, confirm it appears in the discovery list within a few
seconds, join by tap and by code, then unpair on the desktop and confirm both
paths report a pairing problem rather than an invalid code.
