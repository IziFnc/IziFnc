import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';

/// Saldo de hoje (ou "em aberto" no cartão) + o ajuste pendente, se houver.
class AccountBalanceTile extends StatelessWidget {
  const AccountBalanceTile({
    super.key,
    required this.isCard,
    required this.balance,
    required this.pendingTarget,
    required this.onAdjust,
    required this.onUndo,
  });

  final bool isCard;

  /// Saldo com sinal; no cartão é negativo (dívida). `null` enquanto carrega.
  final int? balance;

  /// O que vai virar ao salvar, na mesma unidade que o usuário digitou (saldo
  /// da conta, ou valor em aberto no cartão). `null` = nada pendente.
  final int? pendingTarget;

  final VoidCallback onAdjust;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = balance;
    final shown = value == null
        ? '…'
        : Formatters.money(isCard ? -value : value);
    final pending = pendingTarget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isCard ? 'Em aberto hoje' : 'Saldo hoje'),
                  Text(shown, style: theme.textTheme.titleLarge),
                  if (pending != null)
                    Text(
                      '→ ${Formatters.money(pending)} ao salvar',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (pending != null)
              IconButton(
                tooltip: 'Desfazer ajuste',
                icon: const Icon(Icons.undo),
                onPressed: onUndo,
              ),
            OutlinedButton(
              onPressed: onAdjust,
              child: Text(pending == null ? 'Ajustar saldo' : 'Alterar ajuste'),
            ),
          ],
        ),
      ),
    );
  }
}
