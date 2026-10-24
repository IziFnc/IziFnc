import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/utils/year_month.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import '../support/repo_fixture.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RepoFixture f;
  late AppDatabase db;
  late AccountsRepository accounts;
  late int owner;

  setUp(() async {
    f = await RepoFixture.create();
    db = f.db;
    accounts = f.accounts;
    owner = f.owner;
  });
  tearDown(() => db.close());

  Future<int> spend(int accountId, DateTime date, {int cents = 1000}) => f.spend(accountId, date, cents: cents);
  Future<YearMonth> competenceOf(int entryId) => f.competenceOf(entryId);

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
}
