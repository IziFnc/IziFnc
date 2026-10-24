import 'package:flutter/material.dart';



/// Um item da lista "Antes de começar": feito (✓) ou pendente, com o atalho que
/// resolve a pendência.
class ImportChecklistRow extends StatelessWidget {
  const ImportChecklistRow({
    super.key,
    required this.done,
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.onAction,
    this.checking = false,
  });

  final bool done;

  /// Ainda descobrindo (ex.: lendo a chave do Keystore): sem ✓ nem atalho.
  final bool checking;
  final String title;
  final String hint;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pending = !done && !checking;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: checking
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? colors.primary : colors.onSurfaceVariant,
            ),
      title: Text(title),
      subtitle: pending ? Text(hint) : null,
      trailing: pending ? TextButton(onPressed: onAction, child: Text(actionLabel)) : null,
    );
  }
}

/// Um lembrete da lista "Antes de começar" (sem estado feito/pendente).
class ImportInfoRow extends StatelessWidget {
  const ImportInfoRow({super.key, required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(hint),
    );
  }
}
