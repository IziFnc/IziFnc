import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../accounts/presentation/account_label.dart';


/// Linha de escolha de conta/cartão (ChoiceChips com o ícone da conta).
class EntryAccountChips extends StatelessWidget {
  const EntryAccountChips({
    super.key,
    required this.label,
    required this.options,
    required this.allAccounts,
    required this.selected,
    required this.onSelect,
    this.labelOf,
  });

  final String label;
  final List<Account> options;

  /// Todas as contas: o rótulo de cada uma precisa delas para desambiguar.
  final List<Account> allAccounts;
  final int? selected;
  final void Function(int id) onSelect;
  final String Function(Account)? labelOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in options)
              ChoiceChip(
                avatar: Icon(accountIcon(a), size: 18),
                label: Text(labelOf?.call(a) ?? accountLabel(a, all: allAccounts)),
                selected: a.id == selected,
                onSelected: (_) => onSelect(a.id),
              ),
          ],
        ),
      ],
    );
  }
}
