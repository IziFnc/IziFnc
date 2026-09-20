import 'dart:math';

import '../../../core/utils/year_month.dart';
import '../../accounts/domain/account_kind.dart';

/// A qual mês um lançamento pertence.
///
/// Cada conta tem um **dia de corte** (`startDay`). Por padrão, lançamento **no
/// dia do corte ou depois** já conta para o mês seguinte.
///
/// - Cartão: o corte é o dia de fechamento (o "Até" da planilha). Cartão que
///   fecha dia 26: compra em 25/11 → novembro; em 26/11 → dezembro.
/// - Débito e entradas: o corte é o dia de virada configurado (o dia do
///   salário). Virada dia 27: débito em 27/11 → dezembro.
/// - `startDay == 1` é o mês normal do calendário.
///
/// [cutDayStaysInCurrent] muda o **próprio dia do corte**: com ele, a compra
/// feita nesse dia ainda é da fatura que fecha (só o dia seguinte vai para a
/// próxima). Os bancos divergem — Itaú e Mercado Pago tratam assim, o Nubank
/// manda o dia do fechamento para a fatura seguinte — por isso é uma escolha
/// de cada cartão (ver [competenceForAccount]).
///
/// Corte além do último dia do mês (cartão que fecha dia 30 em fevereiro) cai
/// no último dia — é o que os bancos fazem.
YearMonth competenceOf(
  DateTime date,
  int startDay, {
  bool cutDayStaysInCurrent = false,
}) {
  assert(startDay >= 1 && startDay <= 31, 'startDay fora de 1..31');
  final month = YearMonth.of(date);
  if (startDay == 1) return month;

  final effectiveCut = min(startDay, month.daysInMonth);
  final goesToNext = cutDayStaysInCurrent
      ? date.day > effectiveCut
      : date.day >= effectiveCut;
  return goesToNext ? month.next() : month;
}

/// A competência de um lançamento numa conta ou cartão: escolhe o dia de corte
/// ([cutDayFor]) e, **só no cartão**, a regra do dia do fechamento.
///
/// Conta corrente ignora [closingDayInCurrent]: o dia da virada (o do salário)
/// sempre abre o mês seguinte.
YearMonth competenceForAccount({
  required DateTime date,
  required AccountKind kind,
  required int? closingDay,
  required bool closingDayInCurrent,
  required int monthStartDay,
}) => competenceOf(
  date,
  cutDayFor(kind: kind, closingDay: closingDay, monthStartDay: monthStartDay),
  cutDayStaysInCurrent: kind.isCard && closingDayInCurrent,
);

/// O dia de corte que vale para uma conta.
///
/// Cartão sem fechamento cadastrado cai no mês do calendário em vez de lançar
/// erro — o formulário exige o fechamento, isso é só defesa.
int cutDayFor({
  required AccountKind kind,
  required int? closingDay,
  required int monthStartDay,
}) => kind.isCard ? (closingDay ?? 1) : monthStartDay;
