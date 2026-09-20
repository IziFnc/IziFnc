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

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late EntriesRepository entries;
  late AccountsRepository accounts;
  late SettingsRepository settings;

  /// Conta dona dos cartões criados nos testes (cartão exige uma desde a 0006).
  late int owner;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    entries = EntriesRepository(db);
    accounts = AccountsRepository(db, entries);
    settings = SettingsRepository(db, entries);
    owner = await accounts.create(name: 'Dono', kind: AccountKind.checking);
  });
  tearDown(() => db.close());

  Future<int> spend(int accountId, DateTime date, {int cents = 1000}) =>
      entries.save(
        EntryDraft(
          accountId: accountId,
          type: EntryType.expense,
          description: 'compra',
          amountCents: cents,
          date: date,
        ),
      );

  Future<YearMonth> competenceOf(int entryId) async =>
      YearMonth.fromKey((await entries.find(entryId))!.competence);

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

  group('transferência e pagamento de fatura', () {
    Future<int> transfer(int from, int to, int cents, DateTime date) =>
        entries.save(
          EntryDraft(
            accountId: from,
            toAccountId: to,
            type: EntryType.transfer,
            description: 't',
            amountCents: cents,
            date: date,
          ),
        );

    // Desde a 0006, pagar a fatura é um tipo próprio (conta -> cartão).
    Future<int> pay(int from, int card, int cents, DateTime date) =>
        entries.save(
          EntryDraft(
            accountId: from,
            toAccountId: card,
            type: EntryType.billPayment,
            description: 'fatura',
            amountCents: cents,
            date: date,
          ),
        );

    test('segue a competência da conta de origem', () async {
      await settings.setMonthStartDay(27);
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
      // 23/11 é a data que desempata: pela regra do cartão (fecha 22) seria
      // dezembro; pela da conta (virada 27) é novembro. Vale a da origem.
      final id = await pay(conta, cartao, 5000, DateTime(2025, 11, 23));
      expect(await competenceOf(id), const YearMonth(2025, 11));
    });

    test('não sai de cartão', () async {
      final cartao = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 22,
      );
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      expect(
        () => transfer(cartao, conta, 100, DateTime(2025, 11, 1)),
        throwsArgumentError,
      );
    });

    test('origem igual ao destino é recusado', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      expect(
        () => transfer(conta, conta, 100, DateTime(2025, 11, 1)),
        throwsArgumentError,
      );
    });

    test('transferência sem destino é recusada', () async {
      final conta = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      expect(
        () => entries.save(
          EntryDraft(
            accountId: conta,
            type: EntryType.transfer,
            description: 't',
            amountCents: 1,
            date: DateTime(2025, 11, 1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('despesa com destino é recusada', () async {
      final a = await accounts.create(name: 'A', kind: AccountKind.checking);
      final b = await accounts.create(name: 'B', kind: AccountKind.checking);
      expect(
        () => entries.save(
          EntryDraft(
            accountId: a,
            toAccountId: b,
            type: EntryType.expense,
            description: 'x',
            amountCents: 1,
            date: DateTime(2025, 11, 1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('conta usada só como destino não pode ser excluída', () async {
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
      await pay(conta, cartao, 100, DateTime(2025, 11, 1));
      await expectLater(
        accounts.delete(cartao),
        throwsA(isA<AccountInUseException>()),
      );
    });

    test('watchMonth traz a conta de destino', () async {
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
      await pay(conta, cartao, 100, DateTime(2025, 11, 10));
      final rows = await entries.watchMonth(const YearMonth(2025, 11)).first;
      expect(rows.single.account.name, 'Bradesco');
      expect(rows.single.toAccount?.name, 'Amazon');
    });

    test('transferência para cartão é recusada (use Pagar fatura)', () async {
      final cartao = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 22,
      );
      expect(
        () => transfer(owner, cartao, 100, DateTime(2025, 11, 1)),
        throwsArgumentError,
      );
    });

    test('pagar fatura para uma conta é recusado', () async {
      final c6 = await accounts.create(name: 'C6', kind: AccountKind.checking);
      expect(
        () => pay(owner, c6, 100, DateTime(2025, 11, 1)),
        throwsArgumentError,
      );
    });

    test('pagar fatura não sai de cartão', () async {
      final a = await accounts.create(
        name: 'A',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 5,
      );
      final b = await accounts.create(
        name: 'B',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 5,
      );
      expect(() => pay(a, b, 100, DateTime(2025, 11, 1)), throwsArgumentError);
    });
  });

  group('cartão vinculado à conta (feat 0006)', () {
    test('cartão sem conta dona é recusado', () {
      expect(
        () => accounts.create(
          name: 'Amazon',
          kind: AccountKind.creditCard,
          closingDay: 22,
        ),
        throwsArgumentError,
      );
    });

    test('a dona precisa ser uma conta, não outro cartão', () async {
      final cartao = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 22,
      );
      expect(
        () => accounts.create(
          name: 'Outro',
          kind: AccountKind.creditCard,
          closingDay: 22,
          linkedAccountId: cartao,
        ),
        throwsArgumentError,
      );
    });

    test(
      'editar cartão exige a dona (cartões migrados ganham a sua assim)',
      () async {
        final cartao = await accounts.create(
          name: 'Amazon',
          kind: AccountKind.creditCard,
          linkedAccountId: owner,
          closingDay: 22,
        );
        await expectLater(
          accounts.update(id: cartao, name: 'Amazon', closingDay: 22),
          throwsArgumentError,
        );
        await accounts.update(
          id: cartao,
          name: 'Amazon',
          closingDay: 22,
          linkedAccountId: owner,
        );
        expect((await accounts.find(cartao))!.linkedAccountId, owner);
      },
    );

    test('conta dona de cartão não pode ser excluída', () async {
      await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 22,
      );
      await expectLater(
        accounts.delete(owner),
        throwsA(isA<AccountHasCardsException>()),
      );
      expect(await accounts.find(owner), isNotNull);
    });

    test('conta não guarda dona, mesmo se passarem uma', () async {
      final c6 = await accounts.create(
        name: 'C6',
        kind: AccountKind.checking,
        linkedAccountId: owner,
      );
      expect((await accounts.find(c6))!.linkedAccountId, isNull);
    });
  });

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

  // Regra do dia do fechamento (feat 0012): a compra feita no próprio dia do
  // fechamento fica na fatura atual ou vai para a seguinte, conforme o cartão.
  group('regra do dia do fechamento por cartão', () {
    Future<int> card(String name, {bool? inCurrent, int closing = 26}) =>
        accounts.create(
          name: name,
          kind: AccountKind.creditCard,
          linkedAccountId: owner,
          closingDay: closing,
          closingDayInCurrent: inCurrent ?? true,
        );

    test('cartão novo, sem dizer a regra, nasce com "fatura atual"', () async {
      final id = await accounts.create(
        name: 'Itaú',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 26,
      );

      expect((await accounts.find(id))!.closingDayInCurrent, isTrue);
      final onCut = await spend(id, DateTime(2025, 11, 26));
      final after = await spend(id, DateTime(2025, 11, 27));
      expect(await competenceOf(onCut), const YearMonth(2025, 11));
      expect(await competenceOf(after), const YearMonth(2025, 12));
    });

    test('"próxima fatura": o dia do fechamento já vai para o mês seguinte', () async {
      final id = await card('Nubank', inCurrent: false);

      final onCut = await spend(id, DateTime(2025, 11, 26));
      final before = await spend(id, DateTime(2025, 11, 25));
      expect(await competenceOf(onCut), const YearMonth(2025, 12));
      expect(await competenceOf(before), const YearMonth(2025, 11));
    });

    test('conta corrente não guarda a regra (é só do cartão)', () async {
      final id = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
        closingDayInCurrent: true,
      );

      expect((await accounts.find(id))!.closingDayInCurrent, isFalse);
    });

    test('trocar a regra recalcula só as compras do dia do fechamento, só daquele cartão', () async {
      final itau = await card('Itaú', inCurrent: true);
      final outro = await card('Mercado Pago', inCurrent: true);
      final onCut = await spend(itau, DateTime(2025, 11, 26));
      final other = await spend(itau, DateTime(2025, 11, 10));
      final outroOnCut = await spend(outro, DateTime(2025, 11, 26));
      expect(await competenceOf(onCut), const YearMonth(2025, 11));

      await accounts.update(
        id: itau,
        name: 'Itaú',
        closingDay: 26,
        linkedAccountId: owner,
        closingDayInCurrent: false,
      );

      expect(await competenceOf(onCut), const YearMonth(2025, 12), reason: 'passou a valer "próxima"');
      expect(await competenceOf(other), const YearMonth(2025, 11), reason: 'outro dia: intocado');
      expect(await competenceOf(outroOnCut), const YearMonth(2025, 11), reason: 'outro cartão: intocado');
    });

    test('update sem informar a regra mantém a que o cartão já tinha', () async {
      final id = await card('Nubank', inCurrent: false);
      final onCut = await spend(id, DateTime(2025, 11, 26));

      await accounts.update(id: id, name: 'Nubank Roxinho', closingDay: 26, linkedAccountId: owner);

      expect((await accounts.find(id))!.closingDayInCurrent, isFalse);
      expect(await competenceOf(onCut), const YearMonth(2025, 12));
    });

    test('mudar o fechamento e a regra juntos recalcula uma vez com os dois valores novos', () async {
      final id = await card('Itaú', inCurrent: true, closing: 26);
      final entry = await spend(id, DateTime(2025, 11, 20));

      await accounts.update(
        id: id,
        name: 'Itaú',
        closingDay: 20,
        linkedAccountId: owner,
        closingDayInCurrent: false,
      );

      expect(await competenceOf(entry), const YearMonth(2025, 12), reason: 'fecha dia 20, "próxima": o dia 20 vai para dezembro');
    });
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
