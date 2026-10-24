import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/cents_input_formatter.dart';
import '../domain/entry_type.dart';
import 'entry_account_section.dart';
import 'entry_amount_field.dart';
import 'entry_detail_fields.dart';
import 'entry_type_grid.dart';






/// O corpo rolável do formulário de lançamento: valor, tipo, contas e detalhes.
/// Só desenha: o estado (controllers, tipo, contas, erros) e as regras ficam em
/// [EntryFormScreen]; cada mudança volta por um callback.
class EntryFormFields extends StatelessWidget {
  const EntryFormFields({
    super.key,
    required this.accounts,
    required this.account,
    required this.toAccount,
    required this.balances,
    required this.amount,
    required this.amountFocus,
    required this.interest,
    required this.description,
    required this.note,
    required this.type,
    required this.formTypes,
    required this.date,
    required this.accountId,
    required this.isEditing,
    required this.tourIsHere,
    required this.submitted,
    required this.amountError,
    required this.interestCents,
    required this.onAmountChanged,
    required this.onTypeSelected,
    required this.onFromSelected,
    required this.onToSelected,
    required this.onCardSelected,
    required this.onInterestChanged,
    required this.onPickDate,
    required this.onDescriptionTyped,
  });

  final List<Account> accounts;
  final Account? account;
  final Account? toAccount;
  final Map<int, int> balances;
  final TextEditingController amount;
  final FocusNode amountFocus;
  final TextEditingController interest;
  final TextEditingController description;
  final TextEditingController note;
  final EntryType type;
  final List<EntryType> formTypes;
  final DateTime date;
  final int? accountId;
  final bool isEditing;

  /// Esta tela é a parada do tour: sem foco automático em "Valor", senão o
  /// teclado sobe e cobre a bolha (achado no celular real, feat 0026).
  final bool tourIsHere;
  final bool submitted;
  final String? amountError;
  final int interestCents;
  final VoidCallback onAmountChanged;
  final void Function(EntryType type) onTypeSelected;
  final void Function(int id) onFromSelected;
  final void Function(int id) onToSelected;
  final void Function(int id) onCardSelected;
  final VoidCallback onInterestChanged;
  final VoidCallback onPickDate;
  final VoidCallback onDescriptionTyped;

  @override
  Widget build(BuildContext context) {
    final checking = accounts.where((a) => !a.kind.isCard).toList();
    final cards = accounts.where((a) => a.kind.isCard).toList();
    final paidCents = CentsInputFormatter.parse(amount.text);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EntryAmountField(
          controller: amount,
          focusNode: amountFocus,
          autofocus: !isEditing && !tourIsHere,
          errorText: (submitted && paidCents == 0 ? 'Informe o valor' : null) ?? amountError,
          onChanged: onAmountChanged,
        ),
        const SizedBox(height: 16),
        EntryTypeGrid(
          types: formTypes,
          selected: type,
          tourReady: !isEditing,
          accountIsCard: account?.kind.isCard ?? false,
          checkingCount: checking.length,
          cardCount: cards.length,
          onSelected: onTypeSelected,
        ),
        const SizedBox(height: 16),
        EntryAccountSection(
          type: type,
          accounts: accounts,
          account: account,
          toAccount: toAccount,
          accountId: accountId,
          balances: balances,
          isEditing: isEditing,
          submitted: submitted,
          interest: interest,
          paidCents: paidCents,
          interestCents: interestCents,
          onFromSelected: onFromSelected,
          onToSelected: onToSelected,
          onCardSelected: onCardSelected,
          onInterestChanged: onInterestChanged,
        ),
        const SizedBox(height: 16),
        EntryDetailFields(
          description: description,
          note: note,
          date: date,
          descriptionError: submitted && description.text.trim().isEmpty ? 'Informe a descrição' : null,
          onPickDate: onPickDate,
          onDescriptionTyped: onDescriptionTyped,
        ),
      ],
    );
  }
}
