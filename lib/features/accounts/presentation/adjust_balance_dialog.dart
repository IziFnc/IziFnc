import 'package:flutter/material.dart';

import '../../../core/utils/cents_input_formatter.dart';

/// Pede o valor real (o que o banco mostra). Devolve o alvo em centavos:
/// conta corrente com sinal (cheque especial = negativo); cartão, o valor em
/// aberto. Não grava nada — quem grava é o Salvar da tela.
class AdjustBalanceDialog extends StatefulWidget {
  const AdjustBalanceDialog({super.key, required this.isCard, this.initial});

  final bool isCard;

  /// Ajuste pendente anterior, para editar em vez de redigitar.
  final int? initial;

  @override
  State<AdjustBalanceDialog> createState() => AdjustBalanceDialogState();
}

class AdjustBalanceDialogState extends State<AdjustBalanceDialog> {
  late final _value = TextEditingController(
    text: CentsInputFormatter.format((widget.initial ?? 0).abs()),
  );
  late bool _negative = (widget.initial ?? 0) < 0;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final cents = CentsInputFormatter.parse(_value.text);
    Navigator.of(context).pop(_negative ? -cents : cents);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustar saldo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isCard
                ? 'Quanto o banco mostra em aberto nesta fatura hoje? '
                      'Ao salvar a conta, a diferença vira um ajuste no histórico.'
                : 'Qual o saldo que o banco mostra hoje? '
                      'Ao salvar a conta, a diferença vira um ajuste no histórico.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [CentsInputFormatter()],
            decoration: InputDecoration(
              labelText: widget.isCard ? 'Em aberto' : 'Saldo no banco',
              hintText: 'R\$ 0,00',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (!widget.isCard)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Saldo negativo'),
              value: _negative,
              onChanged: (v) => setState(() => _negative = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Ajustar')),
      ],
    );
  }
}
