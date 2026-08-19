import 'package:flutter/material.dart';

class SonicCard extends StatelessWidget {
  const SonicCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // A light surface needs a much lighter shadow than a dark one to avoid
    // reading as a heavy smudge instead of a subtle lift off the background.
    final shadowAlpha = colorScheme.brightness == Brightness.dark ? 0.19 : 0.08;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowAlpha),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}
