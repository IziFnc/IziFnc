import 'package:drift/drift.dart' show driftRuntimeOptions;
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

  Future<YearMonth> competenceOf(int entryId) => f.competenceOf(entryId);

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
}
