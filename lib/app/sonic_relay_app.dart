import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/sonic_log.dart';
import '../features/listener/presentation/listener_view_model.dart';
import 'di/app_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SonicRelayApp extends ConsumerStatefulWidget {
  const SonicRelayApp({super.key});

  @override
  ConsumerState<SonicRelayApp> createState() => _SonicRelayAppState();
}

class _SonicRelayAppState extends ConsumerState<SonicRelayApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Send the tagged signaling/WebRTC/background lines to the log the user can
    // export, not just to logcat — which is out of reach on the phone that has
    // actually been streaming unattended.
    final diagnosticLog = ref.read(diagnosticLogProvider);
    setSonicLogSink(
      (tag, message) => unawaited(diagnosticLog.write(tag, message)),
    );
  }

  @override
  void dispose() {
    setSonicLogSink(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive/hidden/paused/detached must only ever update UI/service
    // visibility (via the lifecycle controller below), never be treated as an
    // explicit leave — only a user-initiated Stop/Leave, logout, or terminal
    // connection state closes the active stream.
    unawaited(
      ref.read(diagnosticLogProvider).write('Lifecycle', 'app lifecycle -> $state'),
    );
    final inForeground = state == AppLifecycleState.resumed;
    ref
        .read(streamLifecycleControllerProvider)
        .onAppForegroundChanged(inForeground);
    if (inForeground) {
      // Coming back to the foreground is the one moment we can be sure the
      // process is running, so it is the moment to re-check a connection whose
      // recovery may not have survived being backgrounded: Android freezes a
      // process with no foreground service, and a pending reconnect `Timer`
      // does not come back with it. A real outage ended exactly there — the
      // socket's last retry, then nothing across both a network change and a
      // foreground resume, until the user restarted the session by hand.
      ref.read(listenerViewModelProvider.notifier).resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(deviceReadinessProvider);
    return MaterialApp.router(
      title: 'SonicRelay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
