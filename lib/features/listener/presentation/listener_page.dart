import 'package:flutter/material.dart';

import '../../../core/widgets/feature_scaffold.dart';

class ListenerPage extends StatelessWidget {
  const ListenerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureScaffold(
      title: 'Listener',
      description: 'WebRTC audio playback will be implemented in this feature.',
    );
  }
}
