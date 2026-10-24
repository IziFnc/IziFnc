import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../domain/import_plan.dart';
import '../domain/parsed_row.dart';


class ImportSectionHeader extends StatelessWidget {
  const ImportSectionHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          ?trailing,
        ],
      ),
    );
  }
}

class ImportPlanTile extends StatelessWidget {
  const ImportPlanTile({super.key, required this.plan, required this.onToggle});

  final ImportPlanRow plan;
  final void Function(ImportPlanRow plan) onToggle;

  @override
  Widget build(BuildContext context) {
    final row = plan.row;
    final reasonText = switch (plan.reason) {
      ImportSkipReason.duplicate => 'já importado antes',
      ImportSkipReason.suspiciousDate => 'data fora do padrão da aba — confira',
      null => null,
    };
    return CheckboxListTile(
      value: plan.include,
      onChanged: (_) => onToggle(plan),
      title: Text(plan.description),
      subtitle: Text(
        [
          Formatters.date(row.data),
          Formatters.money(row.valorCents),
          // Nome cru da planilha; a conta/cartão de verdade é a do mapeamento.
          ?switch (row.kind) {
            ParsedKind.transfer => '${row.banco} → ${row.destino}',
            ParsedKind.billPayment => '${row.banco} → cartão ${row.destino}',
            _ => null,
          },
          ?reasonText,
        ].join(' · '),
        style: reasonText == null
            ? null
            : TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
