import 'package:flutter/material.dart';

import '../../../core/utils/cents_input_formatter.dart';





/// Campo "Valor" do lançamento, em centavos, com o tamanho de destaque.
class EntryAmountField extends StatelessWidget {
  const EntryAmountField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [CentsInputFormatter()],
      style: Theme.of(context).textTheme.headlineMedium,
      decoration: InputDecoration(
        labelText: 'Valor',
        hintText: 'R\$ 0,00',
        errorText: errorText,
        errorMaxLines: 3,
      ),
      onChanged: (_) => onChanged(),
    );
  }
}
