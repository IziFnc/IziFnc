import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../accounts/presentation/account_label.dart';
import '../domain/entry_type.dart';

/// Ajuste de saldo: só leitura + excluir. Editar o valor não faz sentido — o
/// ajuste é a diferença de um momento; para corrigir, ajusta-se de novo.
class AdjustmentEntryView extends StatelessWidget {
  const AdjustmentEntryView({super.key, required this.entry, required this.account, required this.onDelete});

  final Entry entry;
  final Account? account;

  /// Nulo enquanto está salvando.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final sign = entry.type == EntryType.adjustmentIncrease ? '+' : '−';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuste de saldo'),
        actions: [
          IconButton(
            tooltip: 'Excluir lançamento',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$sign ${Formatters.money(entry.amountCents)}',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (account case final a?) accountLabel(a),
              Formatters.date(entry.date),
            ].join(' · '),
          ),
          const SizedBox(height: 24),
          Text(
            'Ajustes são criados em Contas e cartões → conta → Ajustar saldo, '
            'para o saldo do app bater com o do banco. Para desfazer, exclua.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
