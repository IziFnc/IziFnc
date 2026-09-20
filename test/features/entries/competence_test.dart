import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/utils/year_month.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/domain/competence.dart';

void main() {
  group('competenceOf', () {
    // Casos tirados de uma planilha real de uso.
    final cases = <({String why, DateTime date, int cut, YearMonth expected})>[
      (
        why: 'cartão Caixa: véspera do corte fica no mês',
        date: DateTime(2025, 11, 25),
        cut: 26,
        expected: const YearMonth(2025, 11),
      ),
      (
        why: 'cartão Caixa: no dia do corte já vai pro próximo',
        date: DateTime(2025, 11, 26),
        cut: 26,
        expected: const YearMonth(2025, 12),
      ),
      (
        why: 'cartão Amazon: depois do corte vai pro próximo',
        date: DateTime(2025, 11, 30),
        cut: 22,
        expected: const YearMonth(2025, 12),
      ),
      (
        why: 'débito no dia da virada vai pro próximo',
        date: DateTime(2025, 11, 27),
        cut: 27,
        expected: const YearMonth(2025, 12),
      ),
      (
        why: 'débito na véspera da virada fica no mês',
        date: DateTime(2025, 11, 26),
        cut: 27,
        expected: const YearMonth(2025, 11),
      ),
      (
        why: 'virada no dia 1 é o mês do calendário',
        date: DateTime(2025, 12, 15),
        cut: 1,
        expected: const YearMonth(2025, 12),
      ),
      (
        why: 'virada no dia 1, último dia do mês',
        date: DateTime(2025, 12, 31),
        cut: 1,
        expected: const YearMonth(2025, 12),
      ),
      (
        why: 'corte dia 30 em fevereiro cai no último dia (28)',
        date: DateTime(2026, 2, 28),
        cut: 30,
        expected: const YearMonth(2026, 3),
      ),
      (
        why: 'corte dia 30 em fevereiro, antes do último dia',
        date: DateTime(2026, 2, 27),
        cut: 30,
        expected: const YearMonth(2026, 2),
      ),
      (
        why: 'corte dia 31 em mês de 30 dias',
        date: DateTime(2025, 11, 30),
        cut: 31,
        expected: const YearMonth(2025, 12),
      ),
      (
        why: 'virada de ano',
        date: DateTime(2025, 12, 26),
        cut: 26,
        expected: const YearMonth(2026, 1),
      ),
      (
        why: 'hora do dia não interfere',
        date: DateTime(2025, 11, 25, 23, 59),
        cut: 26,
        expected: const YearMonth(2025, 11),
      ),
    ];

    for (final c in cases) {
      test(c.why, () => expect(competenceOf(c.date, c.cut), c.expected));
    }
  });

  // Alguns bancos (Itaú, Mercado Pago) deixam a compra do dia do fechamento na
  // fatura que fecha; outros (Nubank) mandam para a próxima. O cartão escolhe.
  group('competenceOf — dia do fechamento fica na fatura atual', () {
    YearMonth of(DateTime date, int cut) =>
        competenceOf(date, cut, cutDayStaysInCurrent: true);

    test('no dia do fechamento a compra ainda é da fatura atual', () {
      expect(of(DateTime(2025, 11, 26), 26), const YearMonth(2025, 11));
    });

    test('no dia seguinte ao fechamento já é a próxima fatura', () {
      expect(of(DateTime(2025, 11, 27), 26), const YearMonth(2025, 12));
    });

    test('véspera do fechamento continua na fatura atual', () {
      expect(of(DateTime(2025, 11, 25), 26), const YearMonth(2025, 11));
    });

    test('virada de ano: dia seguinte ao fechamento de dezembro vai para janeiro', () {
      expect(of(DateTime(2025, 12, 27), 26), const YearMonth(2026, 1));
      expect(of(DateTime(2025, 12, 26), 26), const YearMonth(2025, 12));
    });

    test('fechamento dia 30 em fevereiro cai no último dia (28), e o dia 28 ainda é da atual', () {
      expect(of(DateTime(2026, 2, 28), 30), const YearMonth(2026, 2));
      expect(of(DateTime(2026, 2, 27), 30), const YearMonth(2026, 2));
    });

    test('fechamento dia 31 em mês de 30 dias: o dia 30 é o fechamento, ainda da atual', () {
      expect(of(DateTime(2025, 11, 30), 31), const YearMonth(2025, 11));
    });

    test('hora do dia não interfere', () {
      expect(of(DateTime(2025, 11, 26, 23, 59), 26), const YearMonth(2025, 11));
    });

    test('dia 1 continua sendo o mês do calendário', () {
      expect(of(DateTime(2025, 12, 31), 1), const YearMonth(2025, 12));
    });

    test('sem o parâmetro, o comportamento antigo não muda (dia do corte vai para a próxima)', () {
      expect(competenceOf(DateTime(2025, 11, 26), 26), const YearMonth(2025, 12));
    });
  });

  group('competenceForAccount', () {
    YearMonth cardOn(DateTime date, {required bool inCurrent, int closing = 26}) =>
        competenceForAccount(
          date: date,
          kind: AccountKind.creditCard,
          closingDay: closing,
          closingDayInCurrent: inCurrent,
          monthStartDay: 1,
        );

    test('cartão que segue a regra "próxima": dia do fechamento vai para o mês seguinte', () {
      expect(cardOn(DateTime(2025, 11, 26), inCurrent: false), const YearMonth(2025, 12));
    });

    test('cartão que segue a regra "atual": dia do fechamento fica no mês', () {
      expect(cardOn(DateTime(2025, 11, 26), inCurrent: true), const YearMonth(2025, 11));
    });

    test('cartão usa o fechamento e ignora o dia de virada configurado', () {
      final month = competenceForAccount(
        date: DateTime(2025, 11, 20),
        kind: AccountKind.creditCard,
        closingDay: 26,
        closingDayInCurrent: true,
        monthStartDay: 10,
      );
      expect(month, const YearMonth(2025, 11));
    });

    test('conta corrente ignora a regra do cartão: o dia da virada sempre vai para o próximo mês', () {
      for (final inCurrent in [true, false]) {
        final month = competenceForAccount(
          date: DateTime(2025, 11, 27),
          kind: AccountKind.checking,
          closingDay: null,
          closingDayInCurrent: inCurrent,
          monthStartDay: 27,
        );
        expect(month, const YearMonth(2025, 12), reason: 'inCurrent=$inCurrent');
      }
    });

    test('cartão sem fechamento cadastrado cai no calendário (defesa)', () {
      final month = competenceForAccount(
        date: DateTime(2025, 11, 30),
        kind: AccountKind.creditCard,
        closingDay: null,
        closingDayInCurrent: true,
        monthStartDay: 27,
      );
      expect(month, const YearMonth(2025, 11));
    });
  });

  group('cutDayFor', () {
    test('cartão usa o dia de fechamento', () {
      expect(
        cutDayFor(
          kind: AccountKind.creditCard,
          closingDay: 26,
          monthStartDay: 27,
        ),
        26,
      );
    });

    test('conta corrente usa o dia de virada', () {
      expect(
        cutDayFor(
          kind: AccountKind.checking,
          closingDay: null,
          monthStartDay: 27,
        ),
        27,
      );
    });

    test('conta corrente ignora fechamento mesmo se preenchido', () {
      expect(
        cutDayFor(
          kind: AccountKind.checking,
          closingDay: 10,
          monthStartDay: 27,
        ),
        27,
      );
    });

    test('cartão sem fechamento cai no calendário', () {
      expect(
        cutDayFor(
          kind: AccountKind.creditCard,
          closingDay: null,
          monthStartDay: 27,
        ),
        1,
      );
    });
  });
}
