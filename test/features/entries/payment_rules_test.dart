import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/utils/formatters.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/entries/domain/payment_rules.dart';

void main() {
  group('transferBlockedReason', () {
    String? check(int available, int amount) => transferBlockedReason(
      accountName: 'Bradesco',
      availableCents: available,
      amountCents: amount,
    );

    test('transferir exatamente o saldo é permitido', () {
      expect(check(10000, 10000), isNull);
    });

    test('transferir menos que o saldo é permitido', () {
      expect(check(10000, 1), isNull);
    });

    test('um centavo além do saldo é bloqueado, dizendo a conta e o saldo', () {
      final reason = check(10000, 10001)!;
      expect(reason, contains('Saldo insuficiente'));
      expect(reason, contains('Bradesco'));
      expect(reason, contains(Formatters.money(10000)));
    });

    test('conta zerada ou no negativo não transfere nada', () {
      expect(check(0, 1), isNotNull);
      final negative = check(-5000, 100)!;
      expect(negative, contains(Formatters.money(-5000)));
    });
  });

  group('billPaymentBlockedReason', () {
    String? check(int open, int amount) =>
        billPaymentBlockedReason(cardName: 'Amazon', openCents: open, amountCents: amount);

    test('pagar exatamente o que está em aberto é permitido (fatura total)', () {
      expect(check(5000, 5000), isNull);
    });

    test('pagar menos que o em aberto é permitido (pagamento parcial)', () {
      expect(check(5000, 1000), isNull);
    });

    test('pagar acima do em aberto é bloqueado, dizendo o cartão e o valor', () {
      final reason = check(5000, 5001)!;
      expect(reason, contains('Amazon'));
      expect(reason, contains(Formatters.money(5000)));
      expect(reason, contains('em aberto'));
    });

    test('cartão sem nada em aberto não recebe pagamento', () {
      expect(check(0, 100), contains('Não há fatura em aberto'));
    });

    test('cartão com saldo a favor (em aberto negativo) também não recebe', () {
      expect(check(-300, 100), contains('Não há fatura em aberto'));
    });
  });

  // Juros e encargos opcionais (feat 0014): o banco cobra na fatura o que o app
  // ainda não tinha (juros, multa, IOF, anuidade). Ele entra como gasto no
  // cartão e o pagamento passa a poder cobrir o em aberto MAIS o juros.
  group('billPaymentBlockedReason com juros e encargos', () {
    String? check(int open, int amount, int interest) => billPaymentBlockedReason(
      cardName: 'Amazon',
      openCents: open,
      amountCents: amount,
      interestCents: interest,
    );

    test('a fatura pode passar do em aberto até o valor do juros', () {
      expect(check(5000, 5800, 800), isNull);
      expect(check(5000, 5801, 800), isNotNull, reason: 'um centavo além do em aberto + juros');
    });

    test('sem juros, tudo segue como antes (bloqueia acima do em aberto)', () {
      expect(check(5000, 5001, 0), contains('Acima do que está em aberto'));
    });

    test('a mensagem diz o em aberto e o juros informado', () {
      final reason = check(5000, 9000, 800)!;
      expect(reason, contains(Formatters.money(5000)));
      expect(reason, contains(Formatters.money(800)));
    });

    test('cartão sem nada em aberto aceita pagar só o juros (ex.: a fatura veio só com anuidade)', () {
      expect(check(0, 800, 800), isNull);
      expect(check(0, 900, 800), isNotNull);
    });

    test('cartão com crédito (em aberto negativo): a mensagem fala do que dá para pagar, sem valor negativo', () {
      // O crédito vem de pagamentos de fatura maiores que as compras registradas.
      final reason = check(-30000, 30000, 50000)!;
      expect(reason, contains('dá para pagar'));
      expect(reason, contains(Formatters.money(20000)), reason: '-300,00 + 500,00');
      expect(reason, isNot(contains('-')), reason: 'nada de "em aberto -R\$ ..." confuso');
    });

    test('sem em aberto e sem juros continua sem fatura para pagar', () {
      expect(check(0, 100, 0), contains('Não há fatura em aberto'));
    });
  });

  group('billPaymentOutcome — o que sobra no cartão depois de pagar', () {
    test('pagamento total: nada sobra', () {
      expect(billPaymentOutcome(openCents: 5000, paidCents: 5000, interestCents: 0).openAfterCents, 0);
    });

    test('pagamento parcial: a diferença continua em aberto', () {
      expect(billPaymentOutcome(openCents: 5000, paidCents: 2000, interestCents: 0).openAfterCents, 3000);
    });

    test('com juros: entra no em aberto antes de descontar o pagamento', () {
      expect(billPaymentOutcome(openCents: 5000, paidCents: 5800, interestCents: 800).openAfterCents, 0);
      expect(billPaymentOutcome(openCents: 5000, paidCents: 2000, interestCents: 800).openAfterCents, 3800);
    });

    test('quitada e sobra: dizem coisas diferentes', () {
      final paid = billPaymentOutcome(openCents: 5000, paidCents: 5000, interestCents: 0);
      final partial = billPaymentOutcome(openCents: 5000, paidCents: 1000, interestCents: 0);
      expect(paid.isSettled, isTrue);
      expect(partial.isSettled, isFalse);
    });
  });

  group('balanceEffect — o efeito de um lançamento no saldo de uma conta', () {
    int effect(EntryType type, {int account = 1, int? to, int forAccount = 1}) => balanceEffect(
      type: type,
      amountCents: 1000,
      accountId: account,
      toAccountId: to,
      forAccountId: forAccount,
    );

    test('despesa tira, entrada põe', () {
      expect(effect(EntryType.expense), -1000);
      expect(effect(EntryType.income), 1000);
    });

    test('ajuste de saldo: aumento põe, redução tira', () {
      expect(effect(EntryType.adjustmentIncrease), 1000);
      expect(effect(EntryType.adjustmentDecrease), -1000);
    });

    test('transferência tira da origem e põe no destino', () {
      expect(effect(EntryType.transfer, to: 2, forAccount: 1), -1000);
      expect(effect(EntryType.transfer, to: 2, forAccount: 2), 1000);
    });

    test('pagar fatura tira da conta e abate o cartão (saldo do cartão sobe)', () {
      expect(effect(EntryType.billPayment, to: 9, forAccount: 1), -1000);
      expect(effect(EntryType.billPayment, to: 9, forAccount: 9), 1000);
    });

    test('conta que não participa não é afetada', () {
      expect(effect(EntryType.transfer, to: 2, forAccount: 3), 0);
      expect(effect(EntryType.expense, forAccount: 2), 0);
    });
  });
}
