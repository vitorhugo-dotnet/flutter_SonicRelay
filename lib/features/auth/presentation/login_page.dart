import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/sonic_button.dart';
import '../../../core/widgets/sonic_card.dart';
import '../../../core/widgets/sonic_text_field.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.1,
            colors: [Color(0x3328C7A5), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Hear every detail.',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Sign in to monitor your SonicRelay sessions from anywhere.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SonicCard(
                      child: Column(
                        children: [
                          const SonicTextField(
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const SonicTextField(
                            label: 'Password',
                            obscureText: true,
                            prefixIcon: Icons.lock_outline_rounded,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SonicButton(
                            label: 'Sign in',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () => context.go('/join'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Create an account (coming soon)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.accentMuted,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: AppColors.accent),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('SonicRelay', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
