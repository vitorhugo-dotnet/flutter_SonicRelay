import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/sonic_button.dart';
import '../../../core/widgets/sonic_card.dart';

class ListenerPage extends StatelessWidget {
  const ListenerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio monitor'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ConnectionBadge(
                      label: 'Preview disconnected',
                      status: ConnectionStatus.disconnected,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SonicCard(child: _Visualizer()),
                  const SizedBox(height: AppSpacing.md),
                  const Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Latency',
                          value: '-- ms',
                          icon: Icons.speed_rounded,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _MetricCard(
                          label: 'ICE state',
                          value: 'Idle',
                          icon: Icons.hub_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SonicButton(
                    label: 'Leave session',
                    icon: Icons.logout_rounded,
                    isSecondary: true,
                    onPressed: () => context.go('/join'),
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

class _Visualizer extends StatelessWidget {
  const _Visualizer();

  @override
  Widget build(BuildContext context) {
    const heights = [30.0, 52.0, 76.0, 44.0, 88.0, 62.0, 36.0, 70.0, 48.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Live signal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Visualizer preview',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        ExcludeSemantics(
          child: SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final height in heights)
                  Expanded(
                    child: Container(
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.accent, Color(0xFF438BFF)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SonicCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
