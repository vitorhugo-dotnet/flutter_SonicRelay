import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SessionCodeInput extends StatelessWidget {
  const SessionCodeInput({
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      enabled: enabled,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [_UpperCaseTextFormatter()],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Session code',
        hintText: 'SR-4F8K',
        prefixIcon: const Icon(Icons.tag_rounded),
        errorText: errorText,
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
