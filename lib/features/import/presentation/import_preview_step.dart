import 'package:flutter/material.dart';

import '../../entries/domain/entry_type.dart';
import '../domain/build_import_plan.dart';
import '../domain/import_plan.dart';
import '../domain/parsed_row.dart';
import 'import_plan_tiles.dart';

/// Passo 4: a prévia do que vai ser importado, com "desmarcar" por linha/seção.
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

  /// Uma linha ou seção foi (des)marcada: a tela refaz a contagem.
  final VoidCallback onChanged;
  final VoidCallback onConfirm;

  /// Cabeçalho de uma seção da prévia, com "Desmarcar todas / Marcar todas":
  /// tirar uma seção inteira (ex.: as despesas) é um toque, não uma por uma.
  Widget sectionHeader(String label, List<ImportPlanRow> rows) {
    final allOn = rows.every((p) => p.include);
    return ImportSectionHeader(
      label,
      trailing: TextButton(
        onPressed: () {
          for (final p in rows) {
            p.include = !allOn;
          }
          onChanged();
        },
        child: Text(allOn ? 'Desmarcar todas' : 'Marcar todas'),
      ),
    );
  }

  void toggle(ImportPlanRow row) {
    row.include = !row.include;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    List<ImportPlanRow> ofType(EntryType type) => [
      for (final p in plan)
        if (p.type == type) p,
    ];
    final despesas = ofType(EntryType.expense);
    final entradas = ofType(EntryType.income);
    final transferencias = ofType(EntryType.transfer);
    final faturas = ofType(EntryType.billPayment);
    final toImport = plan.where((p) => p.include).length;
    final errors = [...parsed.rowErrors, ...planErrors];

    return Column(
      children: [
        banner,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$toImport de ${plan.length} lançamento(s) serão importados de "$sheetName": '
            '${despesas.length} despesa(s), ${entradas.length} entrada(s), '
            '${transferencias.length} transferência(s) e '
            '${faturas.length} pagamento(s) de fatura. '
            'Desmarque o que não quiser.'
            '${leftOut == 0 ? '' : ' $leftOut linha(s) ficaram de fora nos bancos que você marcou "Não importar".'}'
            '${errors.isEmpty ? '' : ' ${errors.length} linha(s) com erro foram ignoradas.'}',
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              // O que a importação fez diferente da planilha: nada some sem explicação.
              for (final note in importNotes(parsed, plan))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              if (despesas.isNotEmpty) sectionHeader('Despesas', despesas),
              for (final p in despesas)
                ImportPlanTile(plan: p, onToggle: toggle),
              if (entradas.isNotEmpty) sectionHeader('Entradas', entradas),
              for (final p in entradas)
                ImportPlanTile(plan: p, onToggle: toggle),
              if (transferencias.isNotEmpty)
                sectionHeader('Transferências', transferencias),
              for (final p in transferencias)
                ImportPlanTile(plan: p, onToggle: toggle),
              if (faturas.isNotEmpty)
                sectionHeader('Pagamentos de fatura', faturas),
              for (final p in faturas)
                ImportPlanTile(plan: p, onToggle: toggle),
              if (errors.isNotEmpty) ...[
                const ImportSectionHeader('Ignoradas por erro'),
                for (final message in errors)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              onPressed: toImport == 0 || busy ? null : onConfirm,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Importar $toImport lançamento(s)'),
            ),
          ),
        ),
      ],
    );
  }
}
