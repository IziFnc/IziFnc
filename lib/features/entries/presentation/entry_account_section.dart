import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/cents_input_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entry_type.dart';
import 'bill_payment_summary.dart';
import 'entry_account_chips.dart';

/// Escolha de conta(s) conforme o tipo: transferência (De/Para), pagamento de
/// fatura (Cartão/Sai de/juros) ou despesa/entrada (Onde/Conta), com os erros de
/// campo vazio. Vive fora de [EntryFormScreen] só por tamanho; o estado fica lá.
class EntryAccountSection extends StatelessWidget {
  const EntryAccountSection({
    super.key,
    required this.type,
    required this.accounts,
    required this.account,
    required this.toAccount,
    required this.accountId,
    required this.balances,
    required this.isEditing,
    required this.submitted,
    required this.interest,
    required this.paidCents,
    required this.interestCents,
    required this.onFromSelected,
    required this.onToSelected,
    required this.onCardSelected,
    required this.onInterestChanged,
  });

  final EntryType type;
  final List<Account> accounts;

  /// Origem já resolvida (nula se não escolhida ou inválida).
  final Account? account;
  final Account? toAccount;

  /// O que está selecionado em "Onde"/"Conta", sem a normalização de [account].
  final int? accountId;
  final Map<int, int> balances;
  final bool isEditing;
  final bool submitted;
  final TextEditingController interest;
  final int paidCents;
  final int interestCents;
  final void Function(int id) onFromSelected;
  final void Function(int id) onToSelected;
  final void Function(int id) onCardSelected;
  final VoidCallback onInterestChanged;

  @override
  Widget build(BuildContext context) {
    final checking = accounts.where((a) => !a.kind.isCard).toList();
    final cards = accounts.where((a) => a.kind.isCard).toList();
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);

    Widget chips(
      String label,
      List<Account> options,
      int? selected,
      void Function(int) onSelect, {
      String Function(Account)? labelOf,
    }) => EntryAccountChips(
      label: label,
      options: options,
      allAccounts: accounts,
      selected: selected,
      labelOf: labelOf,
      onSelect: onSelect,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...switch (type) {
          EntryType.transfer => [
            chips('De', checking, account?.id, onFromSelected),
            const SizedBox(height: 16),
            chips(
              'Para',
              [
                for (final a in checking)
                  if (a.id != account?.id) a,
              ],
              toAccount?.id,
              onToSelected,
            ),
          ],
          EntryType.billPayment => [
            chips(
              'Cartão',
              cards,
              toAccount?.id,
              onCardSelected,
              labelOf: (card) {
                final open = -(balances[card.id] ?? 0);
                return open > 0
                    ? '${card.name} · ${Formatters.money(open)} em aberto'
                    : card.name;
              },
            ),
            const SizedBox(height: 16),
            chips('Sai de', checking, account?.id, onFromSelected),
            // Ao editar, o juros já é um gasto à parte (editável na lista): o
            // campo só existe ao registrar um pagamento novo.
            if (!isEditing) ...[
              const SizedBox(height: 16),
              TextField(
                controller: interest,
                keyboardType: TextInputType.number,
                inputFormatters: [CentsInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Juros e encargos desta fatura (opcional)',
                  hintText: 'R\$ 0,00',
                  helperText:
                      'Se a fatura do banco veio maior que o em aberto no app, '
                      'coloque aqui a diferença (juros, multa, IOF). Ela vira um '
                      'gasto no cartão.',
                  helperMaxLines: 3,
                ),
                onChanged: (_) => onInterestChanged(),
              ),
              if (toAccount case final to?)
                BillPaymentSummary(
                  openCents: -(balances[to.id] ?? 0),
                  paidCents: paidCents,
                  interestCents: interestCents,
                ),
            ],
          ],
          // Entrada só em conta; despesa em conta (débito, pix) ou cartão (crédito).
          EntryType.income => [
            chips('Conta', checking, accountId, onFromSelected),
          ],
          _ => [chips('Onde', accounts, accountId, onFromSelected)],
        },
        if (submitted && account == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              type.hasDestination ? 'Escolha de onde sai' : 'Escolha a conta',
              style: errorStyle,
            ),
          ),
        if (submitted && type.hasDestination && toAccount == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              type == EntryType.billPayment
                  ? 'Escolha o cartão'
                  : 'Escolha para onde vai',
              style: errorStyle,
            ),
          ),
      ],
    );
  }
}
