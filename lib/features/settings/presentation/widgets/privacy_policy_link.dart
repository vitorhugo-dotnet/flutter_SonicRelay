import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../app/env/app_config.dart';
import '../../../../app/theme/app_spacing.dart';

/// Opens the published SonicRelay privacy policy in the browser.
///
/// Google Play requires the policy to be reachable from inside the app, not
/// only from the store listing, so this lives on the settings screen rather
/// than being left to the listing alone.
///
/// The policy is deliberately a hosted page instead of bundled text: it has to
/// stay in step with what the backend actually does with data (retention,
/// device-identity rotation), and a copy compiled into an installed APK would
/// keep asserting whatever was true on release day.
class PrivacyPolicyLink extends ConsumerStatefulWidget {
  const PrivacyPolicyLink({super.key});

  @override
  ConsumerState<PrivacyPolicyLink> createState() => _PrivacyPolicyLinkState();
}

class _PrivacyPolicyLinkState extends ConsumerState<PrivacyPolicyLink> {
  bool _failed = false;

  Future<void> _open() async {
    final launcher = ref.read(externalLinkLauncherProvider);
    var opened = false;
    try {
      opened = await launcher(Uri.parse(AppConfig.privacyPolicyUrl));
    } catch (_) {
      // A device with no browser, or a platform that rejects the intent. The
      // URL is shown below either way so the policy stays reachable by hand.
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
        TextButton.icon(
          onPressed: _open,
          icon: const Icon(Icons.privacy_tip_outlined, size: 20),
          label: const Text('Privacy policy'),
        ),
        if (_failed) ...[
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            AppConfig.privacyPolicyUrl,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
