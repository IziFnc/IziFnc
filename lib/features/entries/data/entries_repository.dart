import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/year_month.dart';
import '../../accounts/domain/account_kind.dart';
import '../domain/competence.dart';
import '../domain/entry_type.dart';
import '../domain/entry_with_account.dart';

/// O que o formulário manda gravar. `id == null` cria; senão, atualiza.
class EntryDraft {
  const EntryDraft({
    this.id,
    required this.accountId,
    this.toAccountId,
    required this.type,
    required this.description,
    required this.amountCents,
    required this.date,
    this.note,
  });

  final int? id;

  /// A conta do lançamento. Em transferência, a **origem**.
  final int accountId;

  /// Só em transferência: o destino.
  final int? toAccountId;

  final EntryType type;
  final String description;
  final int amountCents;
  final DateTime date;
  final String? note;
}

class EntriesRepository {
  EntriesRepository(this._db);

  final AppDatabase _db;

  /// Lançamentos de um mês de competência, mais recentes primeiro, com a conta
  /// e (em transferência) a conta de destino.
  Stream<List<EntryWithAccount>> watchMonth(YearMonth month) {
    final destination = _db.alias(_db.accounts, 'destination');
    final query =
        _db.select(_db.entries).join([
            innerJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.entries.accountId),
            ),
            leftOuterJoin(
              destination,
              destination.id.equalsExp(_db.entries.toAccountId),
            ),
          ])
          ..where(_db.entries.competence.equals(month.key))
          ..orderBy([
            OrderingTerm.desc(_db.entries.date),
            OrderingTerm.desc(_db.entries.id),
          ]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          EntryWithAccount(
            row.readTable(_db.entries),
            row.readTable(_db.accounts),
            toAccount: row.readTableOrNull(destination),
          ),
      ],
    );
  }

  Future<Entry?> find(int id) => (_db.select(
    _db.entries,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Grava o lançamento calculando a competência. Devolve o id.
  ///
  /// Ajustes de saldo não passam por aqui: use [adjustBalance].
  Future<int> save(EntryDraft draft) async {
    if (draft.type.isAdjustment) {
      throw ArgumentError('Ajuste de saldo é criado por adjustBalance.');
    }
    final account = await _account(draft.accountId);

    if (draft.type.hasDestination) {
      await _checkDestination(draft.type, account, draft.toAccountId);
    } else {
      if (draft.toAccountId != null) {
        throw ArgumentError(
          'Só transferência e pagamento de fatura têm destino.',
        );
      }
      if (account.kind.isCard && draft.type == EntryType.income) {
        // Estorno/cashback em cartão ainda não é suportado.
        throw ArgumentError('Cartão só aceita despesa.');
      }
    }

    final date = DateTime(draft.date.year, draft.date.month, draft.date.day);
    final note = draft.note?.trim();
    final companion = EntriesCompanion(
      accountId: Value(draft.accountId),
      toAccountId: Value(draft.toAccountId),
      type: Value(draft.type),
      description: Value(draft.description.trim()),
      amountCents: Value(draft.amountCents),
      date: Value(date),
      note: Value(note == null || note.isEmpty ? null : note),
      // Transferência segue a regra da origem — o dinheiro sai de lá.
      competence: Value(
        _competenceFor(account, date, await _monthStartDay()).key,
      ),
    );

    final id = draft.id;
    if (id == null) return _db.into(_db.entries).insert(companion);
    await (_db.update(
      _db.entries,
    )..where((e) => e.id.equals(id))).write(companion);
    return id;
  }

  /// Transferência: conta -> outra conta. Pagar fatura: conta -> cartão.
  /// Nos dois casos o dinheiro sai de uma conta, nunca de cartão.
  Future<void> _checkDestination(
    EntryType type,
    Account from,
    int? toAccountId,
  ) async {
    if (from.kind.isCard) {
      throw ArgumentError('O dinheiro sai de uma conta, não de cartão.');
    }
    if (toAccountId == null) throw ArgumentError('Falta o destino.');
    if (toAccountId == from.id) {
      throw ArgumentError('Origem e destino são a mesma conta.');
    }
    final to = await _account(toAccountId); // lança se não existir
    if (type == EntryType.transfer && to.kind.isCard) {
      throw ArgumentError(
        'Transferência é entre contas. Para cartão, use Pagar fatura.',
      );
    }
    if (type == EntryType.billPayment && !to.kind.isCard) {
      throw ArgumentError('Pagar fatura precisa de um cartão como destino.');
    }
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.entries)..where((e) => e.id.equals(id))).go();

  /// Quantos lançamentos existem no total (todos os meses). A home usa para saber
  /// se a pessoa já começou (guia de primeiros passos) e se vale lembrar do backup.
  Stream<int> watchCount() {
    final count = _db.entries.id.count();
    return (_db.selectOnly(_db.entries)..addColumns([count]))
        .map((row) => row.read(count) ?? 0)
        .watchSingle();
  }

  /// Devolve um lançamento excluído, **idêntico** ao que era (mesmo id, data,
  /// competência e criação) — é o "Desfazer" da exclusão. Não recalcula nada:
  /// a linha volta como estava.
  Future<void> restore(Entry entry) =>
      _db.into(_db.entries).insert(entry, mode: InsertMode.insertOrReplace);

  /// Grava vários lançamentos de uma vez — tudo numa transação: ou entram
  /// todos, ou nenhum. Usado pela importação da planilha (feat 0007), que
  /// reaproveita [save] linha a linha para herdar a mesma validação e o
  /// mesmo cálculo de competência de um lançamento manual.
  Future<int> saveAll(List<EntryDraft> drafts) {
    return _db.transaction(() async {
      var count = 0;
      for (final draft in drafts) {
        await save(draft);
        count++;
      }
      return count;
    });
  }

  /// Já existe um lançamento igual a este (mesma conta, tipo, valor,
  /// descrição e data)? Usado pela importação para não duplicar ao
  /// reimportar a mesma aba — a planilha não tem um id estável de linha, só
  /// dá para comparar pelo conteúdo.
  ///
  /// [toAccountId] é o destino de transferência/pagamento de fatura; sem ele,
  /// só casa com lançamento que também não tem destino (despesa, entrada) — duas
  /// transferências do mesmo valor no mesmo dia para contas diferentes não são
  /// duplicata uma da outra.
  Future<bool> hasDuplicate({
    required int accountId,
    int? toAccountId,
    required EntryType type,
    required String description,
    required int amountCents,
    required DateTime date,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final query = _db.select(_db.entries)
      ..where(
        (e) =>
            e.accountId.equals(accountId) &
            (toAccountId == null ? e.toAccountId.isNull() : e.toAccountId.equals(toAccountId)) &
            e.type.equalsValue(type) &
            e.description.equals(description.trim()) &
            e.amountCents.equals(amountCents) &
            e.date.equals(day),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Lançamentos que usam a conta — como origem **ou** destino.
  Future<int> countForAccount(int accountId) async {
    final count = _db.entries.id.count();
    final query = _db.selectOnly(_db.entries)
      ..addColumns([count])
      ..where(
        _db.entries.accountId.equals(accountId) |
            _db.entries.toAccountId.equals(accountId),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Saldo de cada conta, em centavos, com sinal, até [today] (inclusive).
  ///
  /// Uma fórmula só para conta e cartão:
  /// `+ entradas + ajustes de aumento + transferências/pagamentos que chegam`
  /// `- despesas - ajustes de redução - transferências/pagamentos que saem`.
  /// No cartão o resultado fica negativo (é dívida); a tela mostra o oposto
  /// como "em aberto".
  ///
  /// Lançamento com data futura não entra. Somado no SQL: depois da importação
  /// da planilha são milhares de linhas. [today] é fixado na hora de assinar o
  /// Stream — app aberto virando a meia-noite só atualiza na próxima mudança.
  Stream<Map<int, int>> watchBalances({DateTime? today}) =>
      _balancesQuery(today).watch().map(_toBalanceMap);

  Future<int> balanceOf(int accountId, {DateTime? today}) async =>
      _toBalanceMap(await _balancesQuery(today).get())[accountId] ?? 0;

  Selectable<QueryRow> _balancesQuery(DateTime? today) {
    final now = today ?? DateTime.now();
    final cutoff = Variable<DateTime>(DateTime(now.year, now.month, now.day));
    return _db.customSelect(
      '''
      SELECT a.id AS account_id,
        COALESCE((
          SELECT SUM(CASE e.type
            WHEN 'income'             THEN  e.amount_cents
            WHEN 'adjustmentIncrease' THEN  e.amount_cents
            WHEN 'expense'            THEN -e.amount_cents
            WHEN 'adjustmentDecrease' THEN -e.amount_cents
            WHEN 'transfer'           THEN -e.amount_cents
            WHEN 'billPayment'        THEN -e.amount_cents
            ELSE 0 END)
          FROM entries e WHERE e.account_id = a.id AND e.date <= ?1
        ), 0)
        + COALESCE((
          SELECT SUM(e.amount_cents) FROM entries e
          WHERE e.to_account_id = a.id
            AND e.type IN ('transfer', 'billPayment')
            AND e.date <= ?1
        ), 0) AS balance
      FROM accounts a
      ''',
      variables: [cutoff],
      readsFrom: {_db.entries, _db.accounts},
    );
  }

  Map<int, int> _toBalanceMap(List<QueryRow> rows) => {
    for (final row in rows)
      row.read<int>('account_id'): row.read<int>('balance'),
  };

  /// Ajusta o saldo para bater com o banco, registrando a diferença.
  ///
  /// [target] é o que o usuário vê no banco: o saldo da conta corrente (pode
  /// ser negativo) ou, no cartão, o valor **em aberto**. Devolve a diferença
  /// registrada, em centavos com sinal; 0 quando já batia (nada é gravado).
  Future<int> adjustBalance({
    required int accountId,
    required int target,
    DateTime? today,
  }) async {
    final account = await _account(accountId);
    final now = today ?? DateTime.now();
    final date = DateTime(now.year, now.month, now.day);

    // Cartão: "em aberto" é dívida, e dívida é saldo negativo.
    final targetBalance = account.kind.isCard ? -target : target;
    final delta = targetBalance - await balanceOf(accountId, today: date);
    if (delta == 0) return 0;

    await _db
        .into(_db.entries)
        .insert(
          EntriesCompanion.insert(
            accountId: accountId,
            type: delta > 0
                ? EntryType.adjustmentIncrease
                : EntryType.adjustmentDecrease,
            description: 'Ajuste de saldo',
            amountCents: delta.abs(),
            date: date,
            competence: _competenceFor(
              account,
              date,
              await _monthStartDay(),
            ).key,
          ),
        );
    return delta;
  }

  /// Recalcula a competência depois que um dia de corte mudou.
  ///
  /// Filtra por [accountId] (mudou o fechamento de um cartão) ou por [kind]
  /// (mudou o dia de virada, que vale para todas as contas correntes). Só grava
  /// as linhas cujo mês de fato mudou.
  Future<void> recompute({int? accountId, AccountKind? kind}) {
    return _db.transaction(() async {
      final monthStartDay = await _monthStartDay();
      final query = _db.select(_db.entries).join([
        innerJoin(
          _db.accounts,
          _db.accounts.id.equalsExp(_db.entries.accountId),
        ),
      ]);
      if (accountId != null) {
        query.where(_db.entries.accountId.equals(accountId));
      }
      if (kind != null) query.where(_db.accounts.kind.equalsValue(kind));

      for (final row in await query.get()) {
        final entry = row.readTable(_db.entries);
        final account = row.readTable(_db.accounts);
        final competence = _competenceFor(
          account,
          entry.date,
          monthStartDay,
        ).key;
        if (competence == entry.competence) continue;
        await (_db.update(_db.entries)..where((e) => e.id.equals(entry.id)))
            .write(EntriesCompanion(competence: Value(competence)));
      }
    });
  }

  Future<Account> _account(int id) =>
      (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingle();

  /// O mês de um lançamento em [account]: dia de corte + (no cartão) a regra do
  /// dia do fechamento. Única porta para essa conta — não recalcule por fora.
  YearMonth _competenceFor(Account account, DateTime date, int monthStartDay) =>
      competenceForAccount(
        date: date,
        kind: account.kind,
        closingDay: account.closingDay,
        closingDayInCurrent: account.closingDayInCurrent,
        monthStartDay: monthStartDay,
      );

  Future<int> _monthStartDay() async =>
      (await _db.select(_db.appSettings).getSingle()).monthStartDay;
}
