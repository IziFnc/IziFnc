
import '../data/entries_repository.dart';
import '../domain/entry_type.dart';





/// Grava o lançamento. Se há juros e encargos de fatura ([interestCents] > 0,
/// só em pagamento novo, com [cardId] o cartão pago), grava também um gasto no
/// cartão: entra nos totais do mês, ao contrário de um ajuste de saldo, e vai na
/// MESMA transação do pagamento — ou entram os dois, ou nenhum.
Future<void> saveEntryWithInterest(
  EntriesRepository repo,
  EntryDraft draft, {
  required int interestCents,
  required int? cardId,
}) async {
  if (interestCents <= 0) {
    await repo.save(draft);
    return;
  }
  await repo.saveAll([
    EntryDraft(
      accountId: cardId!,
      type: EntryType.expense,
      description: 'Juros e encargos da fatura',
      amountCents: interestCents,
      date: draft.date,
    ),
    draft,
  ]);
}
