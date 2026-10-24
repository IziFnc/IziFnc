import 'package:flutter/material.dart';

import '../../../core/utils/year_month.dart';

/// Rodapé fixo: "Vai para" + Salvar.
///
/// Lançar é a ação do dia a dia e o formulário é mais alto que a tela de um
/// celular pequeno — não dá para exigir rolagem. O "Vai para" fica colado no
/// Salvar porque é na hora de confirmar que importa saber o mês.
class EntryFormFooter extends StatelessWidget {
  const EntryFormFooter({
    super.key,
    required this.competence,
    required this.onSave,
    this.onSaveAndNew,
    this.showSaveAndNew = false,
    this.lastSaved,
  });

  /// Confirmação do último "Salvar e novo" (nula = nada a mostrar).
  final String? lastSaved;

  final YearMonth? competence;
  final VoidCallback? onSave;

  /// "Salvar e novo": grava e deixa o formulário pronto para o próximo. Só ao
  /// criar; [showSaveAndNew] esconde o botão ao editar.
  final VoidCallback? onSaveAndNew;
  final bool showSaveAndNew;

  @override
  Widget build(BuildContext context) {
    final month = competence;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lastSaved != null) ...[
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(lastSaved!, style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (month != null) ...[
              _CompetenceHint(month: month),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (showSaveAndNew) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSaveAndNew,
                      child: const Text('Salvar e novo', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(onPressed: onSave, child: const Text('Salvar')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompetenceHint extends StatelessWidget {
  const _CompetenceHint({required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vai para: ${month.label}',
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
