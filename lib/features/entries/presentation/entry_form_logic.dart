import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/year_month.dart';
import '../data/entries_repository.dart';
import '../domain/competence.dart';
import '../domain/entry_type.dart';

/// Transferência: outra conta (nunca cartão, nunca a própria origem). Pagar
/// fatura: um cartão. Os outros tipos não têm destino.
Account? resolveToAccount(
  EntryType type,
  List<Account> accounts,
  int? toAccountId,
  Account? origin,
) => switch (type) {
  EntryType.transfer =>
    accounts
        .where((a) => a.id == toAccountId && !a.kind.isCard && a.id != origin?.id)
        .firstOrNull,
  EntryType.billPayment => accounts.where((a) => a.id == toAccountId && a.kind.isCard).firstOrNull,
  _ => null,
};

/// A descrição que o formulário sugere enquanto a pessoa não escreve a dela;
/// nulo = nada a sugerir (campo limpo).
String? suggestedDescription(EntryType type, Account? to) => switch (type) {
  EntryType.transfer => 'Transferência',
  EntryType.billPayment => to == null ? 'Pagamento fatura' : 'Pagamento fatura ${to.name}',
  _ => null,
};

/// Exclui na hora e oferece **Desfazer** por alguns segundos, em vez de
/// perguntar antes: perguntar "tem certeza?" todo mundo responde "sim" sem ler,
/// e o erro só aparece depois. O aviso fica no messenger do app (não na tela),
/// então continua visível na lista para onde voltamos.
void showEntryDeletedUndo(ScaffoldMessengerState messenger, EntriesRepository repo, Entry entry) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Lançamento excluído.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'Desfazer', onPressed: () => repo.restore(entry)),
      ),
    );
}

/// Os tipos que o formulário oferece. Ajuste fica de fora de propósito.
const entryFormTypes = [
  EntryType.expense,
  EntryType.income,
  EntryType.transfer,
  EntryType.billPayment,
];

/// O mês que o repositório vai gravar: usa a mesma regra dele (inclusive a do
/// dia do fechamento do cartão), para o "Vai para" nunca discordar.
YearMonth entryCompetence(Account account, int startDay, DateTime date) => competenceForAccount(
  date: date,
  kind: account.kind,
  closingDay: account.closingDay,
  closingDayInCurrent: account.closingDayInCurrent,
  monthStartDay: startDay,
);

Future<DateTime?> pickEntryDate(BuildContext context, DateTime initial) => showDatePicker(
  context: context,
  initialDate: initial,
  firstDate: DateTime(2000),
  lastDate: DateTime(2100),
);
