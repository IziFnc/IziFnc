import 'package:flutter/material.dart';

import '../../entries/domain/entry_type.dart';
import '../domain/build_import_plan.dart';
import '../domain/import_plan.dart';
import '../domain/parsed_row.dart';
import 'import_details_screen.dart';
import 'import_summary_card.dart';

/// Passo 4: a prévia do que vai ser importado, em **resumo** (feat 0049): um cartão
/// por tipo (quantas linhas, quantas marcadas, quanto somam), o que pede revisão e
/// os avisos recolhidos. As linhas uma a uma ficam em "Ver mais detalhes".
class ImportPreviewStep extends StatelessWidget {
  const ImportPreviewStep({
    super.key,
    required this.banner,
    required this.parsed,
    required this.plan,
    required this.planErrors,
    required this.sheetName,
    required this.leftOut,
    required this.busy,
    required this.onChanged,
    required this.onConfirm,
  });

  final Widget banner;
  final ParsedSheetData parsed;
  final List<ImportPlanRow> plan;
  final List<String> planErrors;
  final String? sheetName;
  final int leftOut;
  final bool busy;

  /// Uma linha ou grupo foi (des)marcado: a tela refaz a contagem.
  final VoidCallback onChanged;
  final VoidCallback onConfirm;

  void _setAll(List<ImportPlanRow> rows, bool value) {
    for (final p in rows) {
      p.include = value;
    }
    onChanged();
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ImportDetailsScreen(plan: plan, onChanged: onChanged)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<ImportPlanRow> ofType(EntryType type) => [
      for (final p in plan)
        if (p.type == type) p,
    ];
    final groups = [
      (Icons.shopping_bag_outlined, 'Despesas', ofType(EntryType.expense)),
      (Icons.savings_outlined, 'Entradas', ofType(EntryType.income)),
      (Icons.swap_horiz, 'Transferências', ofType(EntryType.transfer)),
      (Icons.credit_card, 'Pagamentos de fatura', ofType(EntryType.billPayment)),
    ];
    final toImport = plan.where((p) => p.include).length;
    final toReview = plan.where((p) => p.reason != null).length;
    final errors = [...parsed.rowErrors, ...planErrors];
    final notes = [
      ...importNotes(parsed, plan),
      if (leftOut > 0) '$leftOut linha(s) ficaram de fora nos bancos que você marcou "Não importar".',
    ];

    return Column(
      children: [
        banner,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  '$toImport de ${plan.length} lançamento(s) serão importados de "$sheetName".',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final (icon, label, rows) in groups)
                if (rows.isNotEmpty)
                  ImportGroupSummary(
                    icon: icon,
                    label: label,
                    rows: rows,
                    onToggleAll: (value) => _setAll(rows, value),
                  ),
              if (toReview > 0)
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.flag_outlined, color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$toReview ${toReview == 1 ? 'linha veio desmarcada' : 'linhas vieram desmarcadas'} '
                            'para você revisar (já importadas antes, ou com data fora do mês da aba). '
                            'Veja em "Ver mais detalhes".',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: Text('${notes.length} ${notes.length == 1 ? 'aviso' : 'avisos'} sobre esta importação'),
                    children: [
                      for (final note in notes)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(note, style: theme.textTheme.bodySmall),
                          ),
                        ),
                    ],
                  ),
                ),
              if (errors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
                    title: Text(
                      '${errors.length} ${errors.length == 1 ? 'linha ignorada' : 'linhas ignoradas'} por erro',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    children: [
                      for (final message in errors)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(message, style: TextStyle(color: theme.colorScheme.error)),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () => _openDetails(context),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Ver mais detalhes'),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: toImport == 0 || busy ? null : onConfirm,
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Importar $toImport lançamento(s)'),
            ),
          ),
        ),
      ],
    );
  }
}
