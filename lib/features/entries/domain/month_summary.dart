import '../../../core/database/app_database.dart';
import 'entry_type.dart';
import 'entry_with_account.dart';

/// Totais de um mês, no formato da planilha: quanto entrou, quanto saiu no
/// débito e quanto foi para cada cartão.
///
/// Não é saldo (esse é `EntriesRepository.watchBalances`). Transferências e
/// ajustes ficam de fora: pagar a fatura não é gastar de novo.
class MonthSummary {
  const MonthSummary({
    required this.incomeCents,
    required this.debitExpenseCents,
    required this.cards,
  });

  factory MonthSummary.from(Iterable<EntryWithAccount> rows) {
    var income = 0;
    var debit = 0;
    final byCard = <int, ({Account card, int cents})>{};

    for (final EntryWithAccount(:entry, :account) in rows) {
      // Transferência e ajuste não são gasto nem renda (ver affectsMonthTotals).
      if (!entry.type.affectsMonthTotals) continue;
      if (entry.type == EntryType.income) {
        income += entry.amountCents;
      } else if (account.kind.isCard) {
        final current = byCard[account.id];
        byCard[account.id] = (
          card: account,
          cents: (current?.cents ?? 0) + entry.amountCents,
        );
      } else {
        debit += entry.amountCents;
      }
    }

    final cards = byCard.values.toList()
      ..sort(
        (a, b) =>
            a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase()),
      );
    return MonthSummary(
      incomeCents: income,
      debitExpenseCents: debit,
      cards: cards,
    );
  }

  final int incomeCents;
  final int debitExpenseCents;

  /// Só os cartões com lançamento no mês, em ordem alfabética.
  final List<({Account card, int cents})> cards;

  bool get isEmpty =>
      incomeCents == 0 && debitExpenseCents == 0 && cards.isEmpty;
}
