import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_owner_picker.dart';

/// Campos que só o cartão tem: conta dona, dia do fechamento, regra do dia do
/// fechamento e vencimento. Vive fora de [AccountFormScreen] só por tamanho; o
/// estado (controllers e erros) continua lá.
class AccountCardFields extends StatelessWidget {
  const AccountCardFields({
    super.key,
    required this.cardId,
    required this.ownerId,
    required this.ownerError,
    required this.onOwnerSelected,
    required this.closingDay,
    required this.closingError,
    required this.closingInCurrent,
    required this.onClosingInCurrent,
    required this.dueDay,
    required this.dueError,
    required this.onChanged,
  });

  final int? cardId;
  final int? ownerId;
  final String? ownerError;
  final ValueChanged<int> onOwnerSelected;
  final TextEditingController closingDay;
  final String? closingError;
  final bool closingInCurrent;
  final ValueChanged<bool> onClosingInCurrent;
  final TextEditingController dueDay;
  final String? dueError;

  /// Algum campo de texto mudou (a tela refaz os erros).
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        AccountOwnerPicker(
          cardId: cardId,
          selected: ownerId,
          error: ownerError,
          onSelected: onOwnerSelected,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: closingDay,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Dia do fechamento da fatura',
            helperText: 'Como aparece no app do banco (o "Até" da planilha).',
            errorText: closingError,
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 16),
        // Os bancos divergem sobre a compra feita no próprio dia do
        // fechamento, então a escolha é do cartão.
        Text(
          'Compra no dia do fechamento entra na:',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Fatura atual')),
            ButtonSegment(value: false, label: Text('Próxima fatura')),
          ],
          selected: {closingInCurrent},
          onSelectionChanged: (s) => onClosingInCurrent(s.single),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Itaú e Mercado Pago: atual · Nubank: próxima. Confira no app do seu banco.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: dueDay,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Vence no dia (opcional)',
            errorText: dueError,
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
