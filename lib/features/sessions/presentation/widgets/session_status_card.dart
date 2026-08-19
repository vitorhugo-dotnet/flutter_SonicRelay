import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/sonic_button.dart';
import '../../../../core/widgets/sonic_card.dart';

class SessionStatusCard extends StatelessWidget {
  const SessionStatusCard({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SonicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            SonicButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              isSecondary: true,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
