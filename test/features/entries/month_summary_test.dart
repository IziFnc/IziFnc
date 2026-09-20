import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/entries/domain/entry_with_account.dart';
import 'package:izifnc/features/entries/domain/month_summary.dart';

void main() {
  final created = DateTime(2025);
  Account account(int id, String name, AccountKind kind) =>
      Account(
        id: id,
        name: name,
        kind: kind,
        closingDayInCurrent: false,
        createdAt: created,
      );

  var nextId = 0;
  EntryWithAccount row(Account a, EntryType type, int cents) =>
      EntryWithAccount(
        Entry(
          id: nextId++,
          accountId: a.id,
          type: type,
          description: 'x',
          amountCents: cents,
          date: created,
          competence: 202501,
          createdAt: created,
        ),
        a,
      );

  test('separa entradas, débito e cada cartão', () {
    final conta = account(1, 'Bradesco', AccountKind.checking);
    final amazon = account(2, 'Amazon', AccountKind.creditCard);
    final caixa = account(3, 'caixa', AccountKind.creditCard);

    final summary = MonthSummary.from([
      row(conta, EntryType.income, 500000),
      row(conta, EntryType.expense, 51000),
      row(amazon, EntryType.expense, 12999),
      row(amazon, EntryType.expense, 1000),
      row(caixa, EntryType.expense, 3000),
    ]);

    expect(summary.incomeCents, 500000);
    expect(summary.debitExpenseCents, 51000);
    expect(summary.cards.map((c) => (c.card.name, c.cents)), [
      ('Amazon', 13999),
      ('caixa', 3000),
    ]);
  });

  test('transferência e ajuste não entram nos totais', () {
    final conta = account(1, 'Bradesco', AccountKind.checking);
    final cartao = account(2, 'Amazon', AccountKind.creditCard);

    final summary = MonthSummary.from([
      row(cartao, EntryType.expense, 5000),
      row(conta, EntryType.billPayment, 5000), // pagamento da fatura
      row(conta, EntryType.transfer, 4000), // para outra conta
      row(conta, EntryType.adjustmentIncrease, 777),
      row(conta, EntryType.adjustmentDecrease, 333),
    ]);

    expect(summary.incomeCents, 0);
    expect(
      summary.debitExpenseCents,
      0,
      reason: 'pagar a fatura não é gastar de novo',
    );
    expect(summary.cards.single.cents, 5000);
  });

  test('mês sem lançamento é vazio', () {
    expect(MonthSummary.from(const []).isEmpty, isTrue);
  });
}
