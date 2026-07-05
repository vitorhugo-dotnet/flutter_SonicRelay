import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum ConnectionStatus { connected, connecting, disconnected }

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({required this.label, required this.status, super.key});

  final String label;
  final ConnectionStatus status;

  Color get _color => switch (status) {
    ConnectionStatus.connected => AppColors.success,
    ConnectionStatus.connecting => AppColors.warning,
    ConnectionStatus.disconnected => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Connection status: $label',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          border: Border.all(color: _color.withValues(alpha: 0.45)),
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
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: _color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
