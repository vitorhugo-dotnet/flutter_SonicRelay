import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/listener/presentation/listener_page.dart';
import '../../features/pairing/presentation/pairing_page.dart';
import '../../features/pairing/presentation/pairing_view_model.dart';
import '../../features/sessions/presentation/join_session_page.dart';
import '../../features/sessions/presentation/session_waiting_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../di/app_providers.dart';

String? deviceIdentityRedirect(
  DeviceReadinessState readiness,
  String location,
) {
  switch (readiness.status) {
    case DeviceReadinessStatus.restoring:
      return location == '/loading' ? null : '/loading';
    case DeviceReadinessStatus.deviceSetup:
      return location == '/device-setup' ? null : '/device-setup';
    case DeviceReadinessStatus.pairingRequired:
      // Settings must stay reachable here: it holds the server URL field, and a device
      // pointed at the wrong backend can never pair, so redirecting Settings back to /pair
      // left no way to fix it from inside the app. The restoring/deviceSetup branches are
      // deliberately unchanged — before a device credential exists there is no authenticated
      // client for Settings to talk to, and _DeviceSetupPage already owns that retry path.
      return location == '/pair' || location == '/settings' ? null : '/pair';
    case DeviceReadinessStatus.ready:
      if (location == '/loading' || location == '/device-setup') {
        return '/join';
      }
      return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/loading',
    redirect: (context, state) => deviceIdentityRedirect(
      ref.read(deviceReadinessProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/device-setup',
        builder: (context, state) => const _DeviceSetupPage(),
      ),
      GoRoute(path: '/pair', builder: (context, state) => const PairingPage()),
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinSessionPage(),
      ),
      GoRoute(
        path: '/session/waiting',
        builder: (context, state) => const SessionWaitingPage(),
      ),
      GoRoute(
        path: '/listener',
        builder: (context, state) => const ListenerPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
  ref.listen(deviceReadinessProvider, (_, _) => router.refresh());
  ref.listen(pairingViewModelProvider, (previous, next) {
    // Only emissions that carry an authoritative pairing list may drive readiness.
    // A transient loading/submitting emission — and a failed load, whose list can be
    // stale-empty — used to flip readiness to pairingRequired the moment the user
    // opened "Manage pairings", and the redirect above then trapped every route at
    // /pair with no way back to the dashboard.
    if (next.status == PairingStatus.idle ||
        next.status == PairingStatus.paired) {
      ref.read(deviceReadinessProvider.notifier).syncPairings(next.pairings);
    }
    if (previous?.status != PairingStatus.paired &&
        next.status == PairingStatus.paired) {
      router.go('/join');
    }
  });
  ref.onDispose(router.dispose);
  return router;
});

class _DeviceSetupPage extends ConsumerWidget {
  const _DeviceSetupPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(deviceReadinessProvider);
    final error = readiness.errorMessage;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up this device')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phonelink_lock_rounded, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    error ?? 'Preparing a secure identity for this device…',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (error == null)
                    const CircularProgressIndicator()
                  else
                    FilledButton(
                      onPressed: () =>
                          ref.read(deviceReadinessProvider.notifier).retry(),
                      child: Text(
                        readiness.requiresReset
                            ? 'Reset device identity'
                            : 'Retry device setup',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
