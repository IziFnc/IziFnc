import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accounts_providers.dart';

/// "Conta vinculada" do cartão: chips com as contas (nunca outros cartões).
class AccountOwnerPicker extends ConsumerWidget {
  const AccountOwnerPicker({
    super.key,
    required this.cardId,
    required this.selected,
    required this.error,
    required this.onSelected,
  });

  final int? cardId;
  final int? selected;
  final String? error;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owners = [
      for (final a in ref.watch(accountsProvider).value ?? const [])
        if (!a.kind.isCard && a.id != cardId) a,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conta vinculada', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'A conta dona do cartão. É dela que sai o pagamento da fatura.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (owners.isEmpty)
          const Text(
            'Cadastre a conta primeiro (ex.: Bradesco), depois o cartão.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in owners)
                ChoiceChip(
                  avatar: const Icon(Icons.account_balance_outlined, size: 18),
                  label: Text(a.name),
                  selected: a.id == selected,
                  onSelected: (_) => onSelected(a.id),
                ),
            ],
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
