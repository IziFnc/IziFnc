import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/import/data/import_mapping_repository.dart';
import 'package:izifnc/features/import/domain/parsed_row.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late EntriesRepository entries;
  late AccountsRepository accounts;
  late ImportMappingRepository mappings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    entries = EntriesRepository(db);
    accounts = AccountsRepository(db, entries);
    mappings = ImportMappingRepository(db);
  });
  tearDown(() => db.close());

  group('suggest', () {
    test('acha por nome igual (sem acento/caixa) e tipo compatível', () async {
      final owner = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      final card = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.creditCard,
        linkedAccountId: owner,
        closingDay: 10,
      );
      final all = await db.select(db.accounts).get();

      final debit = await mappings.suggest('BRADESCO', SourceTipo.debito, all);
      expect(debit!.id, owner);

      final credit = await mappings.suggest(
        'bradesco',
        SourceTipo.credito,
        all,
      );
      expect(credit!.id, card);
    });

    test('sem conta com o nome, cai no mapeamento salvo', () async {
      final conta = await accounts.create(
        name: 'Conta X',
        kind: AccountKind.checking,
      );
      final all = await db.select(db.accounts).get();

      expect(await mappings.suggest('C6', SourceTipo.debito, all), isNull);

      await mappings.remember('C6', SourceTipo.debito, conta);
      final suggested = await mappings.suggest('C6', SourceTipo.debito, all);
      expect(suggested!.id, conta);
    });

    test('sem nome igual e sem mapeamento salvo, não sugere nada', () async {
      final all = await db.select(db.accounts).get();
      expect(await mappings.suggest('Nubank', SourceTipo.debito, all), isNull);
    });
  });

  group('remember', () {
    test('grava e depois substitui o mapeamento (mesma chave)', () async {
      final a = await accounts.create(name: 'A', kind: AccountKind.checking);
      final b = await accounts.create(name: 'B', kind: AccountKind.checking);

      await mappings.remember('Caixa', SourceTipo.debito, a);
      await mappings.remember('Caixa', SourceTipo.debito, b);

      final all = await db.select(db.accounts).get();
      final suggested = await mappings.suggest('Caixa', SourceTipo.debito, all);
      expect(suggested!.id, b);
    });
  });

  group('EntriesRepository.saveAll / hasDuplicate', () {
    test('saveAll grava tudo numa transação', () async {
      final conta = await accounts.create(
        name: 'Conta',
        kind: AccountKind.checking,
      );
      final count = await entries.saveAll([
        EntryDraft(
          accountId: conta,
          type: EntryType.expense,
          description: 'Mercado',
          amountCents: 1000,
          date: DateTime(2025, 11, 10),
        ),
        EntryDraft(
          accountId: conta,
          type: EntryType.income,
          description: 'Salário',
          amountCents: 500000,
          date: DateTime(2025, 11, 27),
        ),
      ]);

      expect(count, 2);
      expect(await entries.countForAccount(conta), 2);
    });

    test('hasDuplicate detecta lançamento igual já gravado', () async {
      final conta = await accounts.create(
        name: 'Conta',
        kind: AccountKind.checking,
      );
      await entries.save(
        EntryDraft(
          accountId: conta,
          type: EntryType.expense,
          description: 'Mercado',
          amountCents: 1000,
          date: DateTime(2025, 11, 10),
        ),
      );

      expect(
        await entries.hasDuplicate(
          accountId: conta,
          type: EntryType.expense,
          description: 'Mercado',
          amountCents: 1000,
          date: DateTime(2025, 11, 10),
        ),
        isTrue,
      );
      expect(
        await entries.hasDuplicate(
          accountId: conta,
          type: EntryType.expense,
          description: 'Mercado',
          amountCents: 999,
          date: DateTime(2025, 11, 10),
        ),
        isFalse,
      );
    });

    test('transferência: o destino faz parte da identidade da duplicata', () async {
      final origem = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
      final c6 = await accounts.create(name: 'C6', kind: AccountKind.checking);
      final caixa = await accounts.create(name: 'Caixa', kind: AccountKind.checking);
      await entries.save(
        EntryDraft(
          accountId: origem,
          toAccountId: c6,
          type: EntryType.transfer,
          description: 'Transferência',
          amountCents: 170000,
          date: DateTime(2025, 12, 1),
        ),
      );

      Future<bool> dup(int? to, {EntryType type = EntryType.transfer}) => entries.hasDuplicate(
        accountId: origem,
        toAccountId: to,
        type: type,
        description: 'Transferência',
        amountCents: 170000,
        date: DateTime(2025, 12, 1),
      );

      expect(await dup(c6), isTrue, reason: 'mesma origem, destino, valor e dia');
      expect(await dup(caixa), isFalse, reason: 'outro destino não é duplicata');
      expect(await dup(null), isFalse, reason: 'sem destino só casa com lançamento sem destino');
    });

    test('pagamento de fatura: reimportar a mesma fatura é detectado', () async {
      final conta = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
      final cartao = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        linkedAccountId: conta,
        closingDay: 25,
      );
      final draft = EntryDraft(
        accountId: conta,
        toAccountId: cartao,
        type: EntryType.billPayment,
        description: 'Pagamento fatura Amazon',
        amountCents: 80433,
        date: DateTime(2025, 12, 1),
      );
      await entries.saveAll([draft]);

      expect(
        await entries.hasDuplicate(
          accountId: draft.accountId,
          toAccountId: draft.toAccountId,
          type: draft.type,
          description: draft.description,
          amountCents: draft.amountCents,
          date: draft.date,
        ),
        isTrue,
      );
    });
  });
}
