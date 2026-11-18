import 'package:flutter/material.dart';

import '../../entries/domain/entry_type.dart';
import '../domain/import_plan.dart';
import 'import_plan_tiles.dart';

/// "Ver mais detalhes" da prévia (feat 0049): todas as linhas, uma a uma, agrupadas
/// por tipo, para marcar ou desmarcar cada uma. Compartilha o mesmo [plan] da prévia
/// (as linhas são mutáveis), então o que se muda aqui já vale ao voltar.
class ImportDetailsScreen extends StatefulWidget {
  const ImportDetailsScreen({super.key, required this.plan, required this.onChanged});

  final List<ImportPlanRow> plan;

  /// Avisa a prévia (por baixo) que alguma linha mudou, para refazer o resumo.
  final VoidCallback onChanged;

  @override
  State<ImportDetailsScreen> createState() => _ImportDetailsScreenState();
}

class _ImportDetailsScreenState extends State<ImportDetailsScreen> {
  void _toggle(ImportPlanRow row) {
    setState(() => row.include = !row.include);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    const groups = [
      (EntryType.expense, 'Despesas'),
      (EntryType.income, 'Entradas'),
      (EntryType.transfer, 'Transferências'),
      (EntryType.billPayment, 'Pagamentos de fatura'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da importação')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final (type, label) in groups) ...[
            if (widget.plan.any((p) => p.type == type)) ...[
              ImportSectionHeader(
                label,
                trailing: Builder(
                  builder: (context) {
                    final rows = [
                      for (final p in widget.plan)
                        if (p.type == type) p,
                    ];
                    final allOn = rows.every((p) => p.include);
                    return TextButton(
                      onPressed: () {
                        setState(() {
                          for (final p in rows) {
                            p.include = !allOn;
                          }
                        });
                        widget.onChanged();
                      },
                      child: Text(allOn ? 'Desmarcar todas' : 'Marcar todas'),
                    );
                  },
                ),
              ),
              for (final p in widget.plan)
                if (p.type == type) ImportPlanTile(plan: p, onToggle: _toggle),
            ],
          ],
        ],
      ),
    );
  }
}
