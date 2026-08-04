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

    Future<void> select(String? mode) async {
      if (mode == null) return;
      try {
        await ref.read(relayModeProvider.notifier).set(mode);
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
