import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/utils/year_month.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import '../support/repo_fixture.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RepoFixture f;
  late AppDatabase db;
  late EntriesRepository entries;
  late AccountsRepository accounts;
  late int owner;

  setUp(() async {
    f = await RepoFixture.create();
    db = f.db;
    entries = f.entries;
    accounts = f.accounts;
    owner = f.owner;
  });
  tearDown(() => db.close());


  group('saldo', () {
    final today = DateTime(2025, 11, 30);

    Future<void> add(int account, EntryType type, int cents, DateTime date) =>
        entries.save(
          EntryDraft(
            accountId: account,
            type: type,
            description: 'x',
            amountCents: cents,
            date: date,
          ),
        );

    test(
      'conta: entradas, despesas e transferências nos dois sentidos',
      () async {
        final bradesco = await accounts.create(
          name: 'Bradesco',
          kind: AccountKind.checking,
        );
        final c6 = await accounts.create(
          name: 'C6',
          kind: AccountKind.checking,
        );
        await add(bradesco, EntryType.income, 100000, DateTime(2025, 11, 5));
        await add(bradesco, EntryType.expense, 25000, DateTime(2025, 11, 6));
        await entries.save(
          EntryDraft(
            accountId: bradesco,
            toAccountId: c6,
            type: EntryType.transfer,
            description: 't',
            amountCents: 30000,
            date: DateTime(2025, 11, 7),
          ),
        );

        final balances = await entries.watchBalances(today: today).first;
        expect(balances[bradesco], 100000 - 25000 - 30000);
        expect(balances[c6], 30000);
      },
    );

    test('cartão: despesa vira dívida e pagamento abate', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      final cartao = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 22,
      );
      await add(cartao, EntryType.expense, 64371, DateTime(2025, 11, 10));
      await add(cartao, EntryType.expense, 1000, DateTime(2025, 11, 11));
      await entries.save(
        EntryDraft(
          accountId: conta,
          toAccountId: cartao,
          type: EntryType.billPayment,
          description: 'fatura',
          amountCents: 64371,
          date: DateTime(2025, 11, 12),
        ),
      );

      final balances = await entries.watchBalances(today: today).first;
      expect(balances[cartao], -1000, reason: 'R\$ 10,00 em aberto');
      expect(balances[conta], -64371);
    });

    test('lançamento com data futura não entra no saldo de hoje', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      await add(
        conta,
        EntryType.income,
        5000,
        DateTime(2025, 11, 30),
      ); // hoje: entra
      await add(
        conta,
        EntryType.income,
        7000,
        DateTime(2025, 12, 1),
      ); // amanhã: não

      expect(await entries.balanceOf(conta, today: today), 5000);
    });

    test('conta sem lançamento tem saldo zero', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      expect(await entries.balanceOf(conta, today: today), 0);
    });
  });

  group('ajustar saldo', () {
    final today = DateTime(2025, 11, 30);

    test('alvo maior registra aumento e o saldo bate', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      final delta = await entries.adjustBalance(
        accountId: conta,
        target: 50000,
        today: today,
      );

      expect(delta, 50000);
      expect(await entries.balanceOf(conta, today: today), 50000);
      final rows = await entries.watchMonth(const YearMonth(2025, 11)).first;
      expect(rows.single.entry.type, EntryType.adjustmentIncrease);
      expect(rows.single.entry.description, 'Ajuste de saldo');
    });

    test('alvo menor registra redução', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      await entries.adjustBalance(
        accountId: conta,
        target: 50000,
        today: today,
      );
      final delta = await entries.adjustBalance(
        accountId: conta,
        target: 42000,
        today: today,
      );

      expect(delta, -8000);
      expect(await entries.balanceOf(conta, today: today), 42000);
    });

    test('alvo igual não grava nada', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      await entries.adjustBalance(
        accountId: conta,
        target: 50000,
        today: today,
      );
      expect(
        await entries.adjustBalance(
          accountId: conta,
          target: 50000,
          today: today,
        ),
        0,
      );
      expect(await entries.countForAccount(conta), 1);
    });

    test('saldo negativo (cheque especial)', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      await entries.adjustBalance(
        accountId: conta,
        target: -1500,
        today: today,
      );
      expect(await entries.balanceOf(conta, today: today), -1500);
    });

    test('cartão: informa o valor em aberto', () async {
      final cartao = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 22,
      );
      await entries.save(
        EntryDraft(
          accountId: cartao,
          type: EntryType.expense,
          description: 'x',
          amountCents: 1000,
          date: DateTime(2025, 11, 10),
        ),
      );

      // Banco diz que há R$ 30,00 em aberto; o app sabia de R$ 10,00.
      final delta = await entries.adjustBalance(
        accountId: cartao,
        target: 3000,
        today: today,
      );
      expect(delta, -2000, reason: 'mais dívida = saldo mais negativo');
      expect(await entries.balanceOf(cartao, today: today), -3000);
    });

    test('save recusa criar ajuste direto', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      expect(
        () => entries.save(
          EntryDraft(
            accountId: conta,
            type: EntryType.adjustmentIncrease,
            description: 'x',
            amountCents: 1,
            date: today,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('update com ajuste pendente (feat 0005)', () {
    test('grava a conta e o ajuste juntos', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      final delta = await accounts.update(
        id: conta,
        name: 'Bradesco PF',
        adjustTarget: 50000,
      );

      expect(delta, 50000);
      expect((await accounts.find(conta))!.name, 'Bradesco PF');
      expect(await entries.balanceOf(conta), 50000);
    });

    test('sem ajuste pendente não grava lançamento', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      expect(await accounts.update(id: conta, name: 'Outro'), 0);
      expect(await entries.countForAccount(conta), 0);
    });

    test('se o update falha, o ajuste também não é gravado', () async {
      final cartao = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 22,
      );
      // Cartão sem fechamento é recusado: a transação inteira volta.
      await expectLater(
        accounts.update(id: cartao, name: 'Amazon', adjustTarget: 3000),
        throwsArgumentError,
      );
      expect(await entries.countForAccount(cartao), 0);
    });
  });
}
