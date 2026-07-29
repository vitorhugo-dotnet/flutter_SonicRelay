import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/sonic_button.dart';
import '../../../core/widgets/sonic_card.dart';
import 'widgets/keep_playing_toggle.dart';
import 'widgets/relay_mode_toggle.dart';
import 'widgets/server_url_field.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Viewer preferences',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'This viewer uses its own secure device identity.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SonicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SettingsRow(
                          icon: Icons.cloud_outlined,
                          title: 'Server',
                          subtitle: 'SonicRelay API endpoint',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const ServerUrlField(),
                        const Divider(height: AppSpacing.xl),
                        const _SettingsRow(
                          icon: Icons.hub_outlined,
                          title: 'Connection',
                          subtitle: 'ICE transport',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Material(
                          color: Colors.transparent,
                          child: RelayModeToggle(),
                        ),
                        const Divider(height: AppSpacing.xl),
                        const _SettingsRow(
                          icon: Icons.headset_outlined,
                          title: 'Playback',
                          subtitle: 'Background audio',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Material(
                          color: Colors.transparent,
                          child: KeepPlayingToggle(),
                        ),
                        const Divider(height: AppSpacing.xl),
                        const _SettingsRow(
                          icon: Icons.dark_mode_outlined,
                          title: 'Appearance',
                          subtitle: 'Dark theme',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SonicButton(
                    label: 'Manage pairings',
                    icon: Icons.link_rounded,
                    isSecondary: true,
                    onPressed: () => context.push('/pair'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SonicButton(
                    label: 'Reset device identity',
                    icon: Icons.restart_alt_rounded,
                    isSecondary: true,
                    onPressed: () => _confirmReset(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Resetting removes this device credential and requires a new pairing before future sessions.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'SonicRelay mobile viewer',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset device identity?'),
        content: const Text(
          'The secure credential stored on this device will be removed. '
          'You must pair again before joining another session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(deviceReadinessProvider.notifier).resetAndInitialize();
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
