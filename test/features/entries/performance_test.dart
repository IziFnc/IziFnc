import 'package:drift/drift.dart' show DatabaseConnection, Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/utils/year_month.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';

/// Rede de segurança de desempenho (feat 0018): depois de importar planilhas de
/// anos, o banco tem milhares de lançamentos. Saldo e tela do mês precisam
/// continuar instantâneos.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late EntriesRepository entries;
  late List<int> accountIds;

  const total = 20000;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    accountIds = [
      for (var i = 0; i < 8; i++)
        await accounts.create(name: 'Conta $i', kind: AccountKind.checking),
    ];
    // 20 mil lançamentos em ~5 anos, espalhados pelas contas; alguns são
    // transferências (o destino também entra no saldo).
    final start = DateTime(2022);
    await db.batch((batch) {
      batch.insertAll(db.entries, [
        for (var i = 0; i < total; i++)
          EntriesCompanion.insert(
            accountId: accountIds[i % accountIds.length],
            toAccountId: i % 10 == 0
                ? Value<int?>(accountIds[(i + 1) % accountIds.length])
                : const Value<int?>.absent(),
            type: i % 10 == 0 ? EntryType.transfer : (i % 3 == 0 ? EntryType.income : EntryType.expense),
            description: 'Lançamento $i',
            amountCents: 100 + i % 5000,
            date: start.add(Duration(hours: i)),
            competence: 202201 + (i ~/ 350) % 12 + 100 * ((i ~/ 350) ~/ 12),
          ),
      ]);
    });
  });
  tearDown(() => db.close());

  test('o saldo por conta usa o índice (conta + data), não varre a tabela', () async {
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT SUM(e.amount_cents) FROM entries e '
          'WHERE e.account_id = ?1 AND e.date <= ?2',
          variables: [Variable.withInt(accountIds.first), Variable.withInt(0)],
        )
        .get();
    final detail = plan.map((r) => r.read<String>('detail')).join(' | ');
    expect(detail, contains('entries_account_date'));
  });

  test('o saldo do destino de transferência usa o índice do destino', () async {
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT SUM(e.amount_cents) FROM entries e '
          'WHERE e.to_account_id = ?1',
          variables: [Variable.withInt(accountIds.first)],
        )
        .get();
    final detail = plan.map((r) => r.read<String>('detail')).join(' | ');
    expect(detail, contains('entries_to_account'));
  });

  test('saldos de todas as contas com 20 mil lançamentos, dentro de um teto folgado', () async {
    final watch = Stopwatch()..start();
    final balances = await entries.watchBalances(today: DateTime(2030)).first;
    watch.stop();

    expect(balances.keys, unorderedEquals(accountIds));
    // Teto de segurança, não benchmark: com índices leva dezenas de ms; sem eles
    // já passava de segundos em aparelhos modestos.
    expect(watch.elapsedMilliseconds, lessThan(2000), reason: 'saldos demoraram ${watch.elapsedMilliseconds} ms');
  });

  test('um mês da lista continua rápido no meio do histórico grande', () async {
    final watch = Stopwatch()..start();
    final month = await entries.watchMonth(YearMonth(2023, 6)).first;
    watch.stop();

    expect(month, isNotEmpty);
    expect(watch.elapsedMilliseconds, lessThan(2000), reason: 'mês demorou ${watch.elapsedMilliseconds} ms');
  });
}
