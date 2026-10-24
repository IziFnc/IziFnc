import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../domain/payment_rules.dart';

/// Linha ao vivo do pagamento: quanto fica em aberto depois, ou "quitada".
/// Pagar menos que a fatura é permitido: a diferença continua no cartão e
/// entra na próxima fatura, como no banco.
class BillPaymentSummary extends StatelessWidget {
  const BillPaymentSummary({
    super.key,
    required this.openCents,
    required this.paidCents,
    required this.interestCents,
  });

  final int openCents;
  final int paidCents;
  final int interestCents;

  @override
  Widget build(BuildContext context) {
    final paid = paidCents;
    final interest = interestCents;
    // Sem valor, sem nada a pagar ou passando do que dá para pagar: sem resumo
    // (o erro aparece ao salvar; dizer "quitada" aqui enganaria).
    if (paid == 0 || openCents + interest <= 0 || paid > openCents + interest) {
      return const SizedBox.shrink();
    }
    final outcome = billPaymentOutcome(
      openCents: openCents,
      paidCents: paid,
      interestCents: interest,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        outcome.isSettled
            ? 'Fatura quitada.'
            : '${Formatters.money(outcome.openAfterCents)} continuam em aberto '
                  'e entram na próxima fatura.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
