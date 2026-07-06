import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/sonic_card.dart';
import '../../domain/device.dart';
import '../../domain/device_type.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({required this.device, required this.isCurrent, super.key});

  final Device device;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final platform = device.platform == 'ios' ? 'iOS' : 'Android';
    final type = switch (device.type) {
      DeviceType.flutterViewer => 'Flutter viewer',
      DeviceType.windowsPublisher => 'Windows publisher',
    };
    final status = device.revoked
        ? 'Revoked'
        : device.trusted
        ? 'Trusted'
        : 'Not trusted';

    return SonicCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            device.type == DeviceType.flutterViewer
                ? Icons.phone_android_rounded
                : Icons.computer_rounded,
            color: device.revoked ? AppColors.textSecondary : AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$platform · $type',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (isCurrent) const _StatusChip(label: 'Current device'),
                    _StatusChip(label: status, isWarning: device.revoked),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.isWarning = false});

  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: isWarning
          ? Theme.of(context).colorScheme.errorContainer
          : AppColors.accentMuted,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium),
  );
}
