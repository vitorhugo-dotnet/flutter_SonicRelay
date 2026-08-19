import 'package:flutter/material.dart';

import '../../app/theme/sonic_colors.dart';

enum ConnectionStatus { connected, connecting, disconnected }

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({required this.label, required this.status, super.key});

  final String label;
  final ConnectionStatus status;

  Color _color(BuildContext context) => switch (status) {
    ConnectionStatus.connected => context.sonicColors.success,
    ConnectionStatus.connecting => context.sonicColors.warning,
    ConnectionStatus.disconnected => Theme.of(context).colorScheme.error,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Semantics(
      label: 'Connection status: $label',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
