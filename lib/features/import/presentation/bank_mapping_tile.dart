import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../accounts/presentation/account_label.dart';
import '../domain/parsed_row.dart';


class BankMappingTile extends StatelessWidget {
  const BankMappingTile({
    super.key,
    required this.banco,
    required this.tipo,
    required this.accounts,
    required this.selected,
    required this.skipped,
    required this.onSelect,
    required this.onSkip,
    required this.onCreateAccount,
  });

  final String banco;
  final SourceTipo tipo;
  final List<Account> accounts;
  final int? selected;

  /// O usuário marcou este banco como "não importar".
  final bool skipped;
  final void Function(int accountId) onSelect;
  final VoidCallback onSkip;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final wantCard = tipo == SourceTipo.credito;
    final options = accounts.where((a) => a.kind.isCard == wantCard).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$banco (${tipo == SourceTipo.credito ? 'crédito' : 'débito'})',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in options)
                ChoiceChip(
                  avatar: Icon(accountIcon(a), size: 18),
                  label: Text(accountLabel(a, all: accounts)),
                  selected: a.id == selected,
                  onSelected: (_) => onSelect(a.id),
                ),
              // Sempre disponível, inclusive sem conta cadastrada: é como se
              // importa só uma parte da aba.
              ChoiceChip(
                avatar: const Icon(Icons.block, size: 18),
                label: const Text('Não importar'),
                selected: skipped,
                onSelected: (_) => onSkip(),
              ),
              if (options.isEmpty)
                OutlinedButton(
                  onPressed: onCreateAccount,
                  child: Text(
                    wantCard ? 'Cadastre um cartão para "$banco"' : 'Cadastre uma conta para "$banco"',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
