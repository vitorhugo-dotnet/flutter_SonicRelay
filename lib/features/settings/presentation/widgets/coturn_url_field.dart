import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/sonic_button.dart';
import '../../../../core/widgets/sonic_text_field.dart';

/// A TURN URI has the form `turn:host[:port][?transport=...]` (or `turns:` for the TLS
/// variant) — not a `Uri`-parseable http(s) URL, so this is a deliberately minimal sanity
/// check (scheme + non-empty host) rather than a full TURN URI grammar validator.
final _turnUrlPattern = RegExp(r'^turns?:[^\s:]+');

/// Lets the user view and change the coturn (TURN) server URL the backend hands out to every
/// paired device (design spec 2026-08-04). Unlike the API server URL, this is a server-side
/// override, not a local setting — saving calls PUT /api/settings/relay directly.
class CoturnUrlField extends ConsumerStatefulWidget {
  const CoturnUrlField({super.key});

  @override
  ConsumerState<CoturnUrlField> createState() => _CoturnUrlFieldState();
}

class _CoturnUrlFieldState extends ConsumerState<CoturnUrlField> {
  final _controller = TextEditingController();
  String? _error;
  bool _loaded = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _loadFailed = false;
    });
    try {
      final result = await ref.read(relaySettingsApiProvider).fetch();
      if (!mounted) return;
      setState(() {
        _controller.text = result.turnUris.isEmpty ? '' : result.turnUris.first;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      // Distinct from "loaded, and the override happens to be empty" — an empty field here
      // would otherwise look identical to a legitimately-unset override, and a user tapping
      // Save without noticing the load failed would clear the TURN override for every device.
      setState(() {
        _loaded = true;
        _loadFailed = true;
      });
    }
  }

  bool _isValid(String url) => _turnUrlPattern.hasMatch(url);

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isNotEmpty && !_isValid(url)) {
      setState(() {
        _error = 'Enter a valid TURN URL, e.g. turn:your-coturn-server.example.com:3478';
      });
      return;
    }
    try {
      await ref.read(relaySettingsApiProvider).update(
        turnUris: url.isEmpty ? const [] : [url],
      );
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Coturn URL saved.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not save the coturn URL. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_loadFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Could not load the current coturn URL.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.md),
          SonicButton(label: 'Retry', icon: Icons.refresh_outlined, onPressed: _load),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        SonicTextField(
          label: 'Coturn URL',
          controller: _controller,
          keyboardType: TextInputType.url,
          prefixIcon: Icons.dns_outlined,
          errorText: _error,
          hintText: 'turn:your-coturn-server.example.com:3478',
        ),
        const SizedBox(height: AppSpacing.md),
        SonicButton(label: 'Save coturn URL', icon: Icons.save_outlined, onPressed: _save),
      ],
    );
  }
}
