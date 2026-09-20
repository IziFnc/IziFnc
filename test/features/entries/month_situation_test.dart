import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/domain/month_situation.dart';
import 'package:izifnc/features/entries/domain/month_summary.dart';

final _at = DateTime(2025);

Account _account(int id, String name, {AccountKind kind = AccountKind.checking}) =>
    Account(id: id, name: name, kind: kind, closingDayInCurrent: false, createdAt: _at);

void main() {
  final bradesco = _account(1, 'Bradesco');
  final c6 = _account(2, 'C6');
  final amazon = _account(3, 'Amazon', kind: AccountKind.creditCard);
  final nubank = _account(4, 'Nubank', kind: AccountKind.creditCard);
  final accounts = [bradesco, c6, amazon, nubank];

  group('MonthSituation — o que a home mostra de relance', () {
    test('"Em conta" soma só as contas correntes (cartão não entra)', () {
      final s = MonthSituation.from(
        accounts: accounts,
        balances: {1: 361216, 2: 187475, 3: -8990, 4: -21050},
      );
      expect(s.totalCents, 361216 + 187475);
      expect(s.accountBalances.map((b) => b.account.name), ['Bradesco', 'C6']);
    });

    test('"Faturas abertas" vem do saldo negativo do cartão (dívida), e cartão zerado some', () {
      final s = MonthSituation.from(accounts: accounts, balances: {1: 100, 2: 100, 3: -8990, 4: 0});

      expect(s.openCards.map((c) => (c.card.name, c.openCents)), [('Amazon', 8990)]);
      expect(s.openCardsCents, 8990);
    });

    test('vários cartões: o total das faturas é a soma', () {
      final s = MonthSituation.from(accounts: accounts, balances: {1: 0, 2: 0, 3: -8990, 4: -21050});
      expect(s.openCardsCents, 30040);
    });

    test('cartão com crédito (saldo positivo) aparece na lista, mas não abate o total das faturas', () {
      final s = MonthSituation.from(accounts: accounts, balances: {1: 0, 2: 0, 3: 5000, 4: -21050});

      expect(s.openCards.map((c) => (c.card.name, c.openCents)), [('Amazon', -5000), ('Nubank', 21050)]);
      expect(s.openCardsCents, 21050, reason: 'o crédito de um cartão não paga a fatura de outro');
    });

    test('sem cartão em aberto, o total de faturas é zero', () {
      final s = MonthSituation.from(accounts: accounts, balances: {1: 100, 2: 200, 3: 0, 4: 0});
      expect(s.openCards, isEmpty);
      expect(s.openCardsCents, 0);
    });

    test('"Gastou" é o débito mais o que foi para os cartões; "Entrou" são as entradas', () {
      final s = MonthSituation.from(
        accounts: accounts,
        balances: {1: 0, 2: 0, 3: 0, 4: 0},
        summary: MonthSummary(
          incomeCents: 605000,
          debitExpenseCents: 200320,
          cards: [(card: amazon, cents: 21989), (card: nubank, cents: 21050)],
        ),
      );
      expect(s.incomeCents, 605000);
      expect(s.spentCents, 200320 + 21989 + 21050);
      expect(s.summary!.cards, hasLength(2), reason: 'o detalhe por cartão continua disponível para a folha');
    });

    test('sem lançamentos no mês (summary nulo): entrou e gastou zeram', () {
      final s = MonthSituation.from(accounts: accounts, balances: {1: 0, 2: 0, 3: 0, 4: 0});
      expect(s.incomeCents, 0);
      expect(s.spentCents, 0);
    });

    test('conta sem saldo calculado ainda conta como zero', () {
      final s = MonthSituation.from(accounts: accounts, balances: const {});
      expect(s.totalCents, 0);
      expect(s.accountBalances.map((b) => b.cents), [0, 0]);
    });
  });
}
