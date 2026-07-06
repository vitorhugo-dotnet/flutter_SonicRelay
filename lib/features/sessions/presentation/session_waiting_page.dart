import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/sonic_button.dart';
import '../../../core/widgets/sonic_card.dart';
import 'join_session_view_model.dart';

class SessionWaitingPage extends ConsumerWidget {
  const SessionWaitingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(joinSessionViewModelProvider).session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SonicButton(
                label: 'Enter a session code',
                onPressed: () => context.go('/join'),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Preparing stream')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SonicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ConnectionBadge(
                    label: 'Waiting for publisher',
                    status: ConnectionStatus.connecting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Session ${session.sessionId}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Signaling ready: ${session.signalingUrl.host}',
                    overflow: TextOverflow.ellipsis,
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
