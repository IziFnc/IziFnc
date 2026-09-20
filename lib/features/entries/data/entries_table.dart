// O drift le as expressoes de .check() na geracao de codigo; a auto-referencia
// do getter e o padrao documentado dele e nunca executa em runtime.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../accounts/data/accounts_table.dart';
import '../domain/entry_type.dart';

/// Lançamentos (despesas e entradas).
///
/// Chama `Entries`/`Entry` e não `Transactions`/`Transaction` porque o drift
/// já tem uma classe interna `Transaction` e o nome colidiria.
@DataClassName('Entry')
@TableIndex(name: 'entries_competence', columns: {#competence})
// Saldo por conta: `WHERE account_id = ? AND date <= ?` (feat 0018). Sem isto,
// cada conta varre a tabela inteira.
@TableIndex(name: 'entries_account_date', columns: {#accountId, #date})
// Transferência e pagamento de fatura também contam no destino.
@TableIndex(name: 'entries_to_account', columns: {#toAccountId})
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// RESTRICT: conta com lançamento não pode ser excluída. Só vale com
  /// `PRAGMA foreign_keys = ON`, ligado no `beforeOpen` do banco.
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();

  /// Só em transferência: a conta que recebe. Com destino cartão, é o pagamento
  /// da fatura. Adicionada no schema v2 (migração só adiciona a coluna).
  IntColumn get toAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();

  TextColumn get type => textEnum<EntryType>()();

  /// O "Nome" da planilha: texto livre, sem categoria.
  TextColumn get description => text().withLength(min: 1, max: 120)();

  /// Sempre positivo; é o [type] que diz se soma ou subtrai.
  IntColumn get amountCents =>
      integer().check(amountCents.isBiggerThanValue(0))();

  /// Só a data importa; gravada à meia-noite local.
  DateTimeColumn get date => dateTime()();

  /// A "Observação" da planilha.
  TextColumn get note => text().nullable()();

  /// Mês a que o lançamento pertence, `yyyymm`. **Derivado** de [date] + dia de
  /// corte da conta (ver `competenceOf`). Nunca gravar direto: use o
  /// repositório, que recalcula quando o corte muda.
  IntColumn get competence => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
