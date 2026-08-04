import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/sonic_button.dart';
import '../../../../core/widgets/sonic_text_field.dart';

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
    try {
      final result = await ref.read(relaySettingsApiProvider).fetch();
      if (!mounted) return;
      setState(() {
        _controller.text = result.turnUris.isEmpty ? '' : result.turnUris.first;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    try {
      await ref.read(relaySettingsApiProvider).update(
        turnUris: url.isEmpty ? const [] : [url],
      );
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Coturn URL saved.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not save the coturn URL. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
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
