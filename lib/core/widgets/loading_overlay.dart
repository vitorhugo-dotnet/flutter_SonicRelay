import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    required this.isLoading,
    required this.child,
    this.message = 'Loading',
    super.key,
  });

  final bool isLoading;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          // A neutral translucent scrim, not tied to either theme's surface
          // color — the same treatment Material dialogs/modals use regardless
          // of brightness.
          ModalBarrier(dismissible: false, color: Colors.black.withValues(alpha: 0.55)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
