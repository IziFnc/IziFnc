import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/utils/year_month.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/settings/data/settings_repository.dart';
import '../support/repo_fixture.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RepoFixture f;
  late AppDatabase db;
  late EntriesRepository entries;
  late AccountsRepository accounts;
  late SettingsRepository settings;
  late int owner;

  setUp(() async {
    f = await RepoFixture.create();
    db = f.db;
    entries = f.entries;
    accounts = f.accounts;
    settings = f.settings;
    owner = f.owner;
  });
  tearDown(() => db.close());

  Future<int> spend(int accountId, DateTime date, {int cents = 1000}) => f.spend(accountId, date, cents: cents);
  Future<YearMonth> competenceOf(int entryId) => f.competenceOf(entryId);

  test('banco novo nasce com dia de virada 1', () async {
    expect(await settings.watchMonthStartDay().first, 1);
  });

  test(
    'gravar lançamento de cartão calcula a competência pelo fechamento',
    () async {
      final caixa = await accounts.create(
        name: 'Caixa',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 26,
        closingDayInCurrent: false, // regra "próxima fatura" (a do Caixa)
      );
      final before = await spend(caixa, DateTime(2025, 11, 25));
      final onCut = await spend(caixa, DateTime(2025, 11, 26));

      expect(await competenceOf(before), const YearMonth(2025, 11));
      expect(await competenceOf(onCut), const YearMonth(2025, 12));
    },
  );

  test('gravar lançamento de conta usa o dia de virada', () async {
    await settings.setMonthStartDay(27);
    final bradesco = await accounts.create(
      name: 'Bradesco',
      kind: AccountKind.checking,
    );
    final id = await spend(bradesco, DateTime(2025, 11, 27));

    expect(await competenceOf(id), const YearMonth(2025, 12));
  });

  test(
    'mudar o fechamento recalcula só os lançamentos daquele cartão',
    () async {
      final caixa = await accounts.create(
        name: 'Caixa',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 26,
        closingDayInCurrent: false,
      );
      final amazon = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 26,
        closingDayInCurrent: false,
      );
      final caixaEntry = await spend(caixa, DateTime(2025, 11, 26));
      final amazonEntry = await spend(amazon, DateTime(2025, 11, 26));

      await accounts.update(
        id: caixa,
        name: 'Caixa',
        closingDay: 27,
        linkedAccountId: owner,
      );

      expect(
        await competenceOf(caixaEntry),
        const YearMonth(2025, 11),
        reason: 'voltou pro mês',
      );
      expect(
        await competenceOf(amazonEntry),
        const YearMonth(2025, 12),
        reason: 'outro cartão, intocado',
      );
    },
  );

  test('mudar o dia de virada recalcula só as contas correntes', () async {
    final conta = await accounts.create(name: 'C6', kind: AccountKind.checking);
    final cartao = await accounts.create(
      name: 'C6',
      kind: AccountKind.creditCard,
      linkedAccountId: owner,
      closingDay: 14,
    );
    final debit = await spend(conta, DateTime(2025, 11, 28));
    final credit = await spend(cartao, DateTime(2025, 11, 28));

    expect(await competenceOf(debit), const YearMonth(2025, 11));
    await settings.setMonthStartDay(27);

    expect(await competenceOf(debit), const YearMonth(2025, 12));
    expect(
      await competenceOf(credit),
      const YearMonth(2025, 12),
      reason: 'cartão segue o fechamento 14',
    );
  });

  test(
    'watchMonth devolve só o mês pedido, mais recente primeiro, com a conta',
    () async {
      final caixa = await accounts.create(
        name: 'Caixa',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 26,
      );
      await spend(caixa, DateTime(2025, 11, 10));
      await spend(caixa, DateTime(2025, 11, 20));
      await spend(caixa, DateTime(2025, 11, 30)); // dezembro

      final november = await entries
          .watchMonth(const YearMonth(2025, 11))
          .first;
      expect(november.map((e) => e.entry.date.day), [20, 10]);
      expect(november.first.account.name, 'Caixa');
    },
  );

  test('cartão não aceita entrada', () async {
    final caixa = await accounts.create(
      name: 'Caixa',
      kind: AccountKind.creditCard,
      linkedAccountId: owner,
      closingDay: 26,
    );
    expect(
      () => entries.save(
        EntryDraft(
          accountId: caixa,
          type: EntryType.income,
          description: 'x',
          amountCents: 1,
          date: DateTime(2025, 11, 1),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('cartão sem fechamento é recusado', () {
    expect(
      () => accounts.create(
        name: 'X',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
      ),
      throwsArgumentError,
    );
  });

  test('conta com lançamento não pode ser excluída', () async {
    final conta = await accounts.create(
      name: 'Bradesco',
      kind: AccountKind.checking,
    );
    await spend(conta, DateTime(2025, 11, 1));

    await expectLater(
      accounts.delete(conta),
      throwsA(isA<AccountInUseException>()),
    );
    expect(await accounts.find(conta), isNotNull);
  });

  test('o banco também barra a exclusão (foreign key ligada)', () async {
    final conta = await accounts.create(
      name: 'Bradesco',
      kind: AccountKind.checking,
    );
    await spend(conta, DateTime(2025, 11, 1));

    // Pula o repositório de propósito: prova que o PRAGMA foreign_keys está ativo.
    await expectLater(
      (db.delete(db.accounts)..where((a) => a.id.equals(conta))).go(),
      throwsA(isA<SqliteException>()),
    );
  });

  test('desfazer uma exclusão devolve o lançamento idêntico e o saldo volta', () async {
    final id = await spend(owner, DateTime(2026, 9, 10), cents: 2500);
    final before = (await entries.find(id))!;
    final balanceBefore = await entries.balanceOf(owner, today: DateTime(2026, 12, 1));

    await entries.delete(id);
    expect(await entries.find(id), equals(null));
    expect(await entries.balanceOf(owner, today: DateTime(2026, 12, 1)), 0);

    await entries.restore(before);

    final after = (await entries.find(id))!;
    expect(after, before, reason: 'mesma linha: id, data, competência, criação');
    expect(await entries.balanceOf(owner, today: DateTime(2026, 12, 1)), balanceBefore);
  });

  test('desfazer a exclusão de uma transferência devolve os dois lados', () async {
    final other = await accounts.create(name: 'Outra', kind: AccountKind.checking);
    final id = await entries.save(
      EntryDraft(
        accountId: owner,
        toAccountId: other,
        type: EntryType.transfer,
        description: 'Transferência',
        amountCents: 4000,
        date: DateTime(2026, 9, 10),
      ),
    );
    final before = (await entries.find(id))!;

    await entries.delete(id);
    await entries.restore(before);

    final balances = await entries.watchBalances(today: DateTime(2026, 12, 1)).first;
    expect(balances[owner], -4000);
    expect(balances[other], 4000);
  });

  test('conta sem lançamento é excluída', () async {
    final conta = await accounts.create(
      name: 'Bradesco',
      kind: AccountKind.checking,
    );
    await accounts.delete(conta);
    expect(await accounts.find(conta), isNull);
  });

  test('valor zero é recusado pelo banco', () async {
    final conta = await accounts.create(
      name: 'Bradesco',
      kind: AccountKind.checking,
    );
    await expectLater(
      spend(conta, DateTime(2025, 11, 1), cents: 0),
      throwsA(anything),
    );
  });
}
