import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../core/widgets/sonic_card.dart';
import '../join_session_view_model.dart';

/// Sessions of publishers this device is actively paired with, offered for a code-free join.
/// Renders nothing while loading, on a discovery failure, or when nothing is discovered — an
/// idle publisher is the normal case, and a permanent "no sessions" panel would add noise to
/// the primary manual-entry flow. Discovery failures are silent for the same reason: the code
/// field below still works.
class DiscoveredSessionsList extends ConsumerWidget {
  const DiscoveredSessionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoverable = ref.watch(discoverableSessionsProvider);
    return discoverable.when(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        return SonicCard(
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final session in sessions)
                  ListTile(
                    title: Text(session.publisherDeviceName),
                    subtitle: Text(
                      '${session.status} · ${session.viewerCount}/${session.maxViewers} viewers',
                    ),
                    enabled: !session.isFull,
                    onTap: session.isFull
                        ? null
                        : () => ref
                              .read(joinSessionViewModelProvider.notifier)
                              .joinDiscovered(session),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
