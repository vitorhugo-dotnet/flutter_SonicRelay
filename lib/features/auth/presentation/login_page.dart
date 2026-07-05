import 'package:flutter/material.dart';

import '../../../core/widgets/feature_scaffold.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureScaffold(
      title: 'Login',
      description:
          'Sign in support will be added with the backend integration.',
    );
  }
}
