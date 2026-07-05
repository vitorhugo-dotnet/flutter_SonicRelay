import 'package:flutter/material.dart';

import '../../../core/widgets/feature_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureScaffold(
      title: 'Settings',
      description: 'Viewer preferences will be configured here.',
    );
  }
}
