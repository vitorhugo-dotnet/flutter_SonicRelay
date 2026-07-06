import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/sonic_button.dart';
import '../../../core/widgets/sonic_card.dart';
import 'join_session_view_model.dart';
import 'widgets/session_code_input.dart';
import 'widgets/session_status_card.dart';

class JoinSessionPage extends ConsumerWidget {
  const JoinSessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(joinSessionViewModelProvider);
    ref.listen(joinSessionViewModelProvider, (previous, next) {
      if (previous?.status != JoinSessionStatus.joined &&
          next.status == JoinSessionStatus.joined) {
        context.go('/session/waiting');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join session'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ConnectionBadge(
                      label: 'Ready to connect',
                      status: ConnectionStatus.connecting,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Enter session code',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Use the code shown by the SonicRelay Windows publisher.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SonicCard(
                    child: Column(
                      children: [
                        SessionCodeInput(
                          enabled: !state.isJoining,
                          errorText: state.validationMessage,
                          onChanged: ref
                              .read(joinSessionViewModelProvider.notifier)
                              .updateCode,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Codes are temporary and shared by your publisher.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SonicButton(
                          label: 'Join stream',
                          icon: Icons.headphones_rounded,
                          isLoading: state.isJoining,
                          onPressed: ref
                              .read(joinSessionViewModelProvider.notifier)
                              .join,
                        ),
                      ],
                    ),
                  ),
                  if (state.errorMessage case final message?) ...[
                    const SizedBox(height: AppSpacing.md),
                    SessionStatusCard(
                      message: message,
                      onRetry: state.canRetry
                          ? ref
                                .read(joinSessionViewModelProvider.notifier)
                                .retry
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
