import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/utils/year_month.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/settings/data/settings_repository.dart';

/// Banco em memória, repositórios e uma conta dona, prontos para os testes de
/// repositório (divididos por assunto em `test/features/repositories_*_test.dart`).
class RepoFixture {
  RepoFixture._(this.db, this.entries, this.accounts, this.settings, this.owner);

  final AppDatabase db;
  final EntriesRepository entries;
  final AccountsRepository accounts;
  final SettingsRepository settings;

  /// Conta dona dos cartões criados nos testes (cartão exige uma desde a 0006).
  final int owner;

  static Future<RepoFixture> create() async {
    final db = AppDatabase(NativeDatabase.memory());
    final entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    final settings = SettingsRepository(db, entries);
    final owner = await accounts.create(name: 'Dono', kind: AccountKind.checking);
    return RepoFixture._(db, entries, accounts, settings, owner);
  }

  Future<int> spend(int accountId, DateTime date, {int cents = 1000}) => entries.save(
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
}
