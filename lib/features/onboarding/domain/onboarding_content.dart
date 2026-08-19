import 'package:flutter/material.dart';

/// One step of the "how to use SonicRelay" explanation, shared by the
/// first-use onboarding flow and the permanent How to use page so the two
/// never drift apart.
class OnboardingStep {
  const OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const onboardingSteps = [
  OnboardingStep(
    icon: Icons.graphic_eq_rounded,
    title: 'Welcome to SonicRelay',
    body:
        'SonicRelay lets you listen on your phone to audio playing on a '
        'computer, streamed live over WebRTC.',
  ),
  OnboardingStep(
    icon: Icons.desktop_windows_outlined,
    title: 'Prepare your computer',
    body:
        'Install and open SonicRelay Desktop (Publisher) on the computer '
        'that will send audio.',
  ),
  OnboardingStep(
    icon: Icons.play_circle_outline_rounded,
    title: 'Start a session on the PC',
    body:
        'In the publisher, start a session. It shows a QR code and a '
        'pairing code for this phone.',
  ),
  OnboardingStep(
    icon: Icons.qr_code_scanner_rounded,
    title: 'Connect your phone',
    body:
        'Scan the QR code, or enter the Challenge ID and Pairing code '
        'shown on the computer.',
  ),
  OnboardingStep(
    icon: Icons.headphones_rounded,
    title: 'Listen',
    body:
        'Once connected, play audio on the computer and hear it on your '
        'phone in real time.',
  ),
];

const onboardingTroubleshootingTips = [
  'The computer and phone need network connectivity.',
  "If a direct connection isn't possible, SonicRelay can automatically use "
      'a relay (TURN) server.',
  'If a session expires, start a new one on the computer.',
];
