import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../entries/data/entries_repository.dart';
import '../domain/account_kind.dart';

/// Tentativa de excluir uma conta que ainda tem lançamentos.
class AccountInUseException implements Exception {
  const AccountInUseException(this.entryCount);

  final int entryCount;

  @override
  String toString() => 'AccountInUseException($entryCount lançamentos)';
}

/// Tentativa de excluir uma conta que é dona de cartões.
class AccountHasCardsException implements Exception {
  const AccountHasCardsException(this.cardCount);

  final int cardCount;

  @override
  String toString() => 'AccountHasCardsException($cardCount cartões)';
}

class AccountsRepository {
  AccountsRepository(this._db, this._entries);

  final AppDatabase _db;
  final EntriesRepository _entries;

  /// Contas em ordem alfabética; conta antes de cartão quando o nome é igual
  /// (Bradesco conta, Bradesco cartão).
  Stream<List<Account>> watchAll() =>
      (_db.select(_db.accounts)..orderBy([
            (a) => OrderingTerm.asc(a.name.lower()),
            (a) => OrderingTerm.asc(a.kind),
          ]))
          .watch();

  Future<Account?> find(int id) => (_db.select(
    _db.accounts,
  )..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Cria conta ou cartão. Cartão exige fechamento e a conta dona dele
  /// ([linkedAccountId]); conta ignora os três.
  ///
  /// [closingDayInCurrent]: a compra feita no dia do fechamento fica na fatura
  /// que fecha (`true`, o padrão do app para cartão novo) ou vai para a
  /// seguinte. Só vale para cartão; conta corrente guarda sempre `false`.
  Future<int> create({
    required String name,
    required AccountKind kind,
    int? closingDay,
    int? dueDay,
    int? linkedAccountId,
    bool closingDayInCurrent = true,
  }) async {
    if (kind.isCard) {
      if (closingDay == null) {
        throw ArgumentError('Cartão precisa do dia de fechamento.');
      }
      await _checkOwner(linkedAccountId, cardId: null);
    }
    return _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name.trim(),
            kind: kind,
            // Conta não tem fechamento, vencimento nem dona.
            closingDay: Value(kind.isCard ? closingDay : null),
            closingDayInCurrent: Value(kind.isCard && closingDayInCurrent),
            dueDay: Value(kind.isCard ? dueDay : null),
            linkedAccountId: Value(kind.isCard ? linkedAccountId : null),
          ),
        );
  }

  /// A conta dona de um cartão precisa existir e ser conta (não outro cartão).
  Future<void> _checkOwner(int? ownerId, {required int? cardId}) async {
    if (ownerId == null) {
      throw ArgumentError('Cartão precisa da conta a que pertence.');
    }
    if (ownerId == cardId) {
      throw ArgumentError('Cartão não pode ser dono de si.');
    }
    final owner = await find(ownerId);
    if (owner == null) throw ArgumentError('Conta vinculada não existe.');
    if (owner.kind.isCard) {
      throw ArgumentError('Cartão pertence a uma conta, não a outro cartão.');
    }
  }

  /// Cartões cuja conta dona é [accountId].
  Future<int> countCardsOf(int accountId) async {
    final count = _db.accounts.id.count();
    final query = _db.selectOnly(_db.accounts)
      ..addColumns([count])
      ..where(_db.accounts.linkedAccountId.equals(accountId));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Atualiza nome e dias. O tipo não muda depois de criado.
  ///
  /// Se o fechamento de um cartão mudou, os lançamentos dele trocam de mês —
  /// tudo na mesma transação, para a tela nunca ver o meio do caminho.
  ///
  /// [adjustTarget]: o "Ajustar saldo" pendente da tela (ver
  /// [EntriesRepository.adjustBalance]). Vai na **mesma transação**: ou a conta
  /// e o ajuste são gravados juntos, ou nenhum dos dois. Devolve a diferença
  /// registrada (0 sem ajuste ou quando o saldo já batia).
  ///
  /// Cartão exige [linkedAccountId] também na edição: é assim que os cartões
  /// migrados do schema v2 (sem dona) ganham a sua.
  ///
  /// [closingDayInCurrent] `null` mantém a regra que o cartão já tinha. Mudar o
  /// fechamento **ou** a regra recalcula o mês dos lançamentos do cartão.
  Future<int> update({
    required int id,
    required String name,
    int? closingDay,
    int? dueDay,
    int? linkedAccountId,
    bool? closingDayInCurrent,
    int? adjustTarget,
  }) {
    return _db.transaction(() async {
      final before = await (_db.select(
        _db.accounts,
      )..where((a) => a.id.equals(id))).getSingle();
      if (before.kind.isCard) {
        if (closingDay == null) {
          throw ArgumentError('Cartão precisa do dia de fechamento.');
        }
        await _checkOwner(linkedAccountId, cardId: id);
      }
      // Conta corrente não tem a regra; cartão sem novo valor mantém a atual.
      final newRule =
          before.kind.isCard &&
          (closingDayInCurrent ?? before.closingDayInCurrent);

      await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          name: Value(name.trim()),
          closingDay: Value(before.kind.isCard ? closingDay : null),
          closingDayInCurrent: Value(newRule),
          dueDay: Value(before.kind.isCard ? dueDay : null),
          linkedAccountId: Value(before.kind.isCard ? linkedAccountId : null),
        ),
      );

      if (before.kind.isCard &&
          (before.closingDay != closingDay ||
              before.closingDayInCurrent != newRule)) {
        await _entries.recompute(accountId: id);
      }

      // Por último: o ajuste usa o fechamento já atualizado para o mês dele.
      if (adjustTarget == null) return 0;
      return _entries.adjustBalance(accountId: id, target: adjustTarget);
    });
  }

  /// Exclui a conta. Com lançamentos, lança [AccountInUseException] — o banco
  /// também recusaria (RESTRICT), isto só dá uma mensagem melhor.
  ///
  /// Conta dona de cartões lança [AccountHasCardsException] — exclua ou
  /// revincule os cartões antes.
  Future<void> delete(int id) async {
    final count = await _entries.countForAccount(id);
    if (count > 0) throw AccountInUseException(count);
    final cards = await countCardsOf(id);
    if (cards > 0) throw AccountHasCardsException(cards);
    await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
  }
}
