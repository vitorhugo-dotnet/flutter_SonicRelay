import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(description, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/join'),
                    child: const Text('Join a session'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/listener'),
                    child: const Text('Listener'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/settings'),
                    child: const Text('Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
