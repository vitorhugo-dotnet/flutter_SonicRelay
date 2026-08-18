import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../app/env/app_config.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// Invites the listener to fund the infrastructure the app runs on.
///
/// SonicRelay is free and ad-free, but the signaling and TURN servers behind
/// every session are paid for by the maintainer. This is the only place the
/// app asks for anything, so it states the reason plainly rather than showing
/// a bare donate button.
///
/// [compact] drops the explanation and keeps the button alone, for screens
/// that already carry their own footer copy (Settings).
class SupportProjectCard extends ConsumerStatefulWidget {
  const SupportProjectCard({this.compact = false, super.key});

  final bool compact;

  @override
  ConsumerState<SupportProjectCard> createState() => _SupportProjectCardState();
}

class _SupportProjectCardState extends ConsumerState<SupportProjectCard> {
  bool _failed = false;

  Future<void> _open() async {
    final launcher = ref.read(externalLinkLauncherProvider);
    var opened = false;
    try {
      opened = await launcher(Uri.parse(AppConfig.donationUrl));
    } catch (_) {
      // A device with no browser, or a platform that rejects the intent. The
      // URL is shown below either way so the page stays reachable by hand.
      opened = false;
    }
    if (!mounted) return;
    setState(() => _failed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            'SonicRelay runs on servers I pay for. Buying a coffee keeps the '
            'relay online.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _DonationButton(onPressed: _open),
        if (_failed) ...[
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            AppConfig.donationUrl,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _DonationButton extends StatelessWidget {
  const _DonationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accentMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('☕', style: TextStyle(fontSize: 22)),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Buy me a coffee',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Icon(Icons.favorite, color: AppColors.warning, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
