// O drift le as expressoes de .check() na geracao de codigo; a auto-referencia
// do getter e o padrao documentado dele e nunca executa em runtime.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../domain/account_kind.dart';

/// Contas e cartões de crédito.
///
/// **Débito é da conta; cartão é sempre crédito** e pertence a uma conta
/// ([linkedAccountId]): o cartão Amazon é do Bradesco. Compra no débito ou pix
/// é lançada na conta. O tipo não muda depois de criado (o formulário trava) —
/// trocar cartão por conta com lançamentos existentes deixaria a competência
/// deles sem sentido.
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  TextColumn get kind => textEnum<AccountKind>()();

  /// Só cartão: a conta dona dele (sugerida como origem no "Pagar fatura").
  /// Nula nos cartões criados antes do schema v3 — a tela pede para vincular.
  IntColumn get linkedAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Só cartão: dia de fechamento (o "Até"). Por padrão, compra neste dia ou
  /// depois vai para o mês seguinte; ver [closingDayInCurrent].
  IntColumn get closingDay =>
      integer().nullable().check(closingDay.isBetweenValues(1, 31))();

  /// Só cartão: a compra feita **no próprio dia do fechamento** fica na fatura
  /// que fecha (`true`) ou vai para a seguinte (`false`)? Os bancos divergem
  /// (Itaú e Mercado Pago: atual; Nubank: seguinte), então é do cartão.
  ///
  /// O padrão do **banco** é `false`: é o comportamento que existia antes desta
  /// coluna, então os cartões já cadastrados não mudam de mês sozinhos. Cartão
  /// novo nasce `true` (padrão do app, em `AccountsRepository.create`).
  BoolColumn get closingDayInCurrent =>
      boolean().withDefault(const Constant(false))();

  /// Só cartão: dia de vencimento da fatura. Nesta versão, só exibido.
  IntColumn get dueDay =>
      integer().nullable().check(dueDay.isBetweenValues(1, 31))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
