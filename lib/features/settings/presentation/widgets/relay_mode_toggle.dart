import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../core/webrtc/relay_modes.dart';

/// Lets the viewer choose how ICE connects — automatic (direct with relay fallback), forced
/// relay-only, or relay disabled entirely — instead of the old force-relay-only toggle. The
/// choice applies locally right away (see [relayModeProvider]) and is shared with the user's
/// paired devices through the backend's per-device relay settings.
class RelayModeToggle extends ConsumerWidget {
  const RelayModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relayMode = ref.watch(relayModeProvider);

    Future<void> select(String? mode) async {
      if (mode == null) return;
      try {
        await ref.read(relayModeProvider.notifier).set(mode);
        // Share the choice with paired devices through the backend. Not
        // awaited: best-effort sync must not block the toggle on the network.
        unawaited(ref.read(relaySettingsSyncProvider).pushRelayMode(mode));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not save the relay mode. Please try again.'),
            ),
          );
      }
    }

    return RadioGroup<String>(
      groupValue: relayMode,
      onChanged: select,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: RelayModes.automatic,
            title: Text('Automatic'),
            subtitle: Text(
              'Prefer a direct connection; fall back to the relay if it fails.',
            ),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: RelayModes.forceRelay,
            title: Text('Force relay (TURN only)'),
            subtitle: Text(
              'Always route audio through the relay server. Useful on restrictive networks.',
            ),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: RelayModes.disableFallback,
            title: Text('Disable relay fallback'),
            subtitle: Text(
              'Only connect directly; never fall back to the relay if it fails.',
            ),
          ),
        ],
      ),
    );
  }
}
