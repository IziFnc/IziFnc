import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../domain/import_plan.dart';

/// O resumo de um grupo da prévia da importação (feat 0049): quantas linhas, quantas
/// estão marcadas e quanto somam, com **um** interruptor para o grupo inteiro. As
/// linhas uma a uma ficam em "Ver mais detalhes".
class ImportGroupSummary extends StatelessWidget {
  const ImportGroupSummary({
    super.key,
    required this.icon,
    required this.label,
    required this.rows,
    required this.onToggleAll,
  });

  final IconData icon;
  final String label;
  final List<ImportPlanRow> rows;

  /// Marca ou desmarca o grupo inteiro (o valor novo vem do interruptor).
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = rows.where((r) => r.include).toList();
    final review = rows.where((r) => r.reason != null).length;
    final total = on.fold<int>(0, (sum, r) => sum + r.row.valorCents);
    final allOn = on.length == rows.length;

    final summary = [
      '${on.length} de ${rows.length} ${rows.length == 1 ? 'marcada' : 'marcadas'}',
      if (on.isNotEmpty) Formatters.money(total),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(icon, size: 20, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleSmall),
                  Text(summary, style: theme.textTheme.bodyMedium),
                  if (review > 0)
                    Text(
                      '$review para revisar',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                ],
              ),
            ),
            Semantics(
              label: 'Importar todas as linhas de $label',
              child: Switch(value: allOn, onChanged: onToggleAll),
            ),
          ],
        ),
      ),
    );
  }
}
