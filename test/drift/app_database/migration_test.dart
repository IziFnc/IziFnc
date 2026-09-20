// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // Mesmo a v2 só adicionando coluna, este teste fica: é dinheiro de alguém.
  // Os dados imitam o que existe no emulador desde a feat 0003 (virada 27,
  // cartão Caixa fechando 26, compra de 26/11 com observação).
  test(
    'migração v1 -> v2 preserva contas, lançamentos e configurações',
    () async {
      const createdAt = 1764115200; // 2025-11-26, segundos desde a epoch
      const nov26 = 1764115200;

      final oldAccountsData = <v1.AccountsData>[
        const v1.AccountsData(
          id: 1,
          name: 'Caixa',
          kind: 'creditCard',
          closingDay: 26,
          dueDay: 5,
          createdAt: createdAt,
        ),
        const v1.AccountsData(
          id: 2,
          name: 'Bradesco',
          kind: 'checking',
          createdAt: createdAt,
        ),
      ];
      final expectedNewAccountsData = <v2.AccountsData>[
        const v2.AccountsData(
          id: 1,
          name: 'Caixa',
          kind: 'creditCard',
          closingDay: 26,
          dueDay: 5,
          createdAt: createdAt,
        ),
        const v2.AccountsData(
          id: 2,
          name: 'Bradesco',
          kind: 'checking',
          createdAt: createdAt,
        ),
      ];

      final oldEntriesData = <v1.EntriesData>[
        const v1.EntriesData(
          id: 1,
          accountId: 1,
          type: 'expense',
          description: 'Compra dia 26',
          amountCents: 1000,
          date: nov26,
          competence: 202512,
          createdAt: createdAt,
        ),
        const v1.EntriesData(
          id: 2,
          accountId: 2,
          type: 'income',
          description: 'Salário',
          amountCents: 450000,
          date: nov26,
          note: '13º p1',
          competence: 202511,
          createdAt: createdAt,
        ),
      ];
      final expectedNewEntriesData = <v2.EntriesData>[
        // to_account_id nasce nulo: nenhum lançamento antigo é transferência.
        const v2.EntriesData(
          id: 1,
          accountId: 1,
          type: 'expense',
          description: 'Compra dia 26',
          amountCents: 1000,
          date: nov26,
          competence: 202512,
          createdAt: createdAt,
        ),
        const v2.EntriesData(
          id: 2,
          accountId: 2,
          type: 'income',
          description: 'Salário',
          amountCents: 450000,
          date: nov26,
          note: '13º p1',
          competence: 202511,
          createdAt: createdAt,
        ),
      ];

      final oldAppSettingsData = <v1.AppSettingsData>[
        const v1.AppSettingsData(id: 1, monthStartDay: 27),
      ];
      final expectedNewAppSettingsData = <v2.AppSettingsData>[
        const v2.AppSettingsData(id: 1, monthStartDay: 27),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.accounts, oldAccountsData);
          batch.insertAll(oldDb.entries, oldEntriesData);
          batch.insertAll(oldDb.appSettings, oldAppSettingsData);
        },
        validateItems: (newDb) async {
          expect(
            expectedNewAccountsData,
            await newDb.select(newDb.accounts).get(),
          );
          expect(
            expectedNewEntriesData,
            await newDb.select(newDb.entries).get(),
          );
          expect(
            expectedNewAppSettingsData,
            await newDb.select(newDb.appSettings).get(),
          );
        },
      );
    },
  );

  // v3: pagar a fatura deixou de ser transferência. O que era "transfer" para
  // um cartão vira "billPayment"; transferência entre contas continua igual.
  // Os dados imitam o emulador depois da 0004 (Bradesco -> fatura Caixa).
  test(
    'migração v2 -> v3 separa pagamento de fatura de transferência',
    () async {
      const createdAt = 1757721600; // 2025-09-13
      const sep13 = 1757721600;

      final oldAccountsData = <v2.AccountsData>[
        const v2.AccountsData(
          id: 1,
          name: 'Caixa',
          kind: 'creditCard',
          closingDay: 27,
          dueDay: 5,
          createdAt: createdAt,
        ),
        const v2.AccountsData(
          id: 2,
          name: 'Bradesco',
          kind: 'checking',
          createdAt: createdAt,
        ),
        const v2.AccountsData(
          id: 3,
          name: 'C6',
          kind: 'checking',
          createdAt: createdAt,
        ),
      ];
      final expectedNewAccountsData = <v3.AccountsData>[
        // Cartão existente sai sem conta dona: a tela pede para vincular.
        const v3.AccountsData(
          id: 1,
          name: 'Caixa',
          kind: 'creditCard',
          closingDay: 27,
          dueDay: 5,
          createdAt: createdAt,
        ),
        const v3.AccountsData(
          id: 2,
          name: 'Bradesco',
          kind: 'checking',
          createdAt: createdAt,
        ),
        const v3.AccountsData(
          id: 3,
          name: 'C6',
          kind: 'checking',
          createdAt: createdAt,
        ),
      ];

      final oldEntriesData = <v2.EntriesData>[
        const v2.EntriesData(
          id: 1,
          accountId: 1,
          type: 'expense',
          description: 'Compra dia 26',
          amountCents: 1000,
          date: sep13,
          competence: 202509,
          createdAt: createdAt,
        ),
        const v2.EntriesData(
          id: 2,
          accountId: 2,
          toAccountId: 1,
          type: 'transfer',
          description: 'Pagamento fatura Caixa',
          amountCents: 1000,
          date: sep13,
          competence: 202509,
          createdAt: createdAt,
        ),
        const v2.EntriesData(
          id: 3,
          accountId: 2,
          toAccountId: 3,
          type: 'transfer',
          description: 'Transferência',
          amountCents: 5000,
          date: sep13,
          competence: 202509,
          createdAt: createdAt,
        ),
        const v2.EntriesData(
          id: 4,
          accountId: 2,
          type: 'adjustmentIncrease',
          description: 'Ajuste de saldo',
          amountCents: 50000,
          date: sep13,
          competence: 202509,
          createdAt: createdAt,
        ),
      ];
      final expectedNewEntriesData = <v3.EntriesData>[
        const v3.EntriesData(
          id: 1,
          accountId: 1,
          type: 'expense',
          description: 'Compra dia 26',
          amountCents: 1000,
          date: sep13,
          competence: 202509,
          createdAt: createdAt,
        ),
        // Era transferência para cartão: agora é pagamento de fatura.
        const v3.EntriesData(
          id: 2,
          accountId: 2,
          toAccountId: 1,
          type: 'billPayment',
          description: 'Pagamento fatura Caixa',
          amountCents: 1000,
          date: sep13,
          competence: 202509,
          createdAt: createdAt,
        ),
        // Conta -> conta: continua transferência.
        const v3.EntriesData(
          id: 3,
          accountId: 2,
          toAccountId: 3,
          type: 'transfer',
          description: 'Transferência',
          amountCents: 5000,
          date: sep13,
          competence: 202509,
          createdAt: createdAt,
        ),
        const v3.EntriesData(
          id: 4,
          accountId: 2,
          type: 'adjustmentIncrease',
          description: 'Ajuste de saldo',
          amountCents: 50000,
          date: sep13,
          competence: 202509,
          createdAt: createdAt,
        ),
      ];

      final oldAppSettingsData = <v2.AppSettingsData>[
        const v2.AppSettingsData(id: 1, monthStartDay: 27),
      ];
      final expectedNewAppSettingsData = <v3.AppSettingsData>[
        const v3.AppSettingsData(id: 1, monthStartDay: 27),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.accounts, oldAccountsData);
          batch.insertAll(oldDb.entries, oldEntriesData);
          batch.insertAll(oldDb.appSettings, oldAppSettingsData);
        },
        validateItems: (newDb) async {
          expect(
            expectedNewAccountsData,
            await newDb.select(newDb.accounts).get(),
          );
          expect(
            expectedNewEntriesData,
            await newDb.select(newDb.entries).get(),
          );
          expect(
            expectedNewAppSettingsData,
            await newDb.select(newDb.appSettings).get(),
          );
        },
      );
    },
  );

  // v4: só adiciona a tabela import_bank_mappings (feat 0007). Contas e
  // lançamentos existentes não podem ser tocados; a tabela nova nasce vazia.
  test(
    'migração v3 -> v4 só cria import_bank_mappings, sem tocar no resto',
    () async {
      const createdAt = 1757721600; // 2025-09-13

      final oldAccountsData = <v3.AccountsData>[
        const v3.AccountsData(
          id: 1,
          name: 'Bradesco',
          kind: 'checking',
          createdAt: createdAt,
        ),
      ];
      final expectedNewAccountsData = <v4.AccountsData>[
        const v4.AccountsData(
          id: 1,
          name: 'Bradesco',
          kind: 'checking',
          createdAt: createdAt,
        ),
      ];

      final oldEntriesData = <v3.EntriesData>[
        const v3.EntriesData(
          id: 1,
          accountId: 1,
          type: 'income',
          description: 'Salário',
          amountCents: 450000,
          date: createdAt,
          competence: 202509,
          createdAt: createdAt,
        ),
      ];
      final expectedNewEntriesData = <v4.EntriesData>[
        const v4.EntriesData(
          id: 1,
          accountId: 1,
          type: 'income',
          description: 'Salário',
          amountCents: 450000,
          date: createdAt,
          competence: 202509,
          createdAt: createdAt,
        ),
      ];

      final oldAppSettingsData = <v3.AppSettingsData>[
        const v3.AppSettingsData(id: 1, monthStartDay: 27),
      ];
      final expectedNewAppSettingsData = <v4.AppSettingsData>[
        const v4.AppSettingsData(id: 1, monthStartDay: 27),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.accounts, oldAccountsData);
          batch.insertAll(oldDb.entries, oldEntriesData);
          batch.insertAll(oldDb.appSettings, oldAppSettingsData);
        },
        validateItems: (newDb) async {
          expect(
            expectedNewAccountsData,
            await newDb.select(newDb.accounts).get(),
          );
          expect(
            expectedNewEntriesData,
            await newDb.select(newDb.entries).get(),
          );
          expect(
            expectedNewAppSettingsData,
            await newDb.select(newDb.appSettings).get(),
          );
          expect(await newDb.select(newDb.importBankMappings).get(), isEmpty);
        },
      );
    },
  );

  // v5 só adiciona colunas em app_settings. O que importa: quem já usava o app
  // mantém o dia de virada e tudo o mais, e passa a valer "segue o sistema,
  // texto normal, contraste normal".
  test(
    'migração v4 -> v5 preserva os dados e dá o padrão de aparência',
    () async {
      const at = 1764115200;
      final oldAccounts = <v4.AccountsData>[
        const v4.AccountsData(id: 1, name: 'Bradesco', kind: 'checking', createdAt: at),
      ];
      final oldEntries = <v4.EntriesData>[
        const v4.EntriesData(
          id: 1,
          accountId: 1,
          type: 'expense',
          description: 'Mercado',
          amountCents: 12345,
          date: at,
          competence: 202511,
          createdAt: at,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 4,
        newVersion: 5,
        createOld: v4.DatabaseAtV4.new,
        createNew: v5.DatabaseAtV5.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.accounts, oldAccounts);
          batch.insertAll(oldDb.entries, oldEntries);
          batch.insertAll(oldDb.appSettings, [
            const v4.AppSettingsData(id: 1, monthStartDay: 27),
          ]);
        },
        validateItems: (newDb) async {
          expect(await newDb.select(newDb.accounts).get(), hasLength(1));
          final entries = await newDb.select(newDb.entries).get();
          expect(entries.single.description, 'Mercado');
          expect(entries.single.amountCents, 12345);
          final settings = await newDb.select(newDb.appSettings).getSingle();
          expect(settings.monthStartDay, 27);
          expect(settings.themeMode, 0);
          expect(settings.textScale, 1.0);
          expect(settings.highContrast, 0);
        },
      );
    },
  );

  // v6 só adiciona a regra do dia do fechamento ao cartão. O que importa: quem
  // já tinha cartões continua com a regra de sempre (o dia do fechamento vai
  // para a fatura seguinte) e nenhum lançamento muda de mês.
  test(
    'migração v5 -> v6 mantém os cartões na regra antiga e não mexe nos lançamentos',
    () async {
      const at = 1764115200;
      final oldAccounts = <v5.AccountsData>[
        const v5.AccountsData(id: 1, name: 'Caixa conta', kind: 'checking', createdAt: at),
        const v5.AccountsData(
          id: 2,
          name: 'Caixa',
          kind: 'creditCard',
          linkedAccountId: 1,
          closingDay: 26,
          dueDay: 5,
          createdAt: at,
        ),
      ];
      // Compra feita exatamente no dia do fechamento (26/11): pela regra antiga
      // já está em dezembro (202512), e tem de continuar lá.
      final oldEntries = <v5.EntriesData>[
        const v5.EntriesData(
          id: 1,
          accountId: 2,
          type: 'expense',
          description: 'Compra no dia do fechamento',
          amountCents: 9990,
          date: at,
          competence: 202512,
          createdAt: at,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 5,
        newVersion: 6,
        createOld: v5.DatabaseAtV5.new,
        createNew: v6.DatabaseAtV6.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.accounts, oldAccounts);
          batch.insertAll(oldDb.entries, oldEntries);
          batch.insertAll(oldDb.appSettings, [
            const v5.AppSettingsData(
              id: 1,
              monthStartDay: 1,
              themeMode: 0,
              textScale: 1.0,
              highContrast: 0,
            ),
          ]);
        },
        validateItems: (newDb) async {
          final accounts = await newDb.select(newDb.accounts).get();
          expect(accounts.map((a) => a.name), ['Caixa conta', 'Caixa']);
          final card = accounts.singleWhere((a) => a.name == 'Caixa');
          expect(card.closingDay, 26);
          expect(card.linkedAccountId, 1);
          expect(card.closingDayInCurrent, 0, reason: 'cartão existente segue a regra antiga (0 = falso)');

          final entry = await newDb.select(newDb.entries).getSingle();
          expect(entry.description, 'Compra no dia do fechamento');
          expect(entry.competence, 202512, reason: 'o mês do lançamento não muda');
        },
      );
    },
  );

  // v7 só acrescenta: a data do último backup (nula = nunca) e dois índices que
  // aceleram o saldo. Nenhuma linha existente pode mudar.
  test(
    'migração v6 -> v7 preserva tudo, começa sem backup e cria os índices de saldo',
    () async {
      const at = 1764115200;
      final oldAccounts = <v6.AccountsData>[
        const v6.AccountsData(
          id: 1,
          name: 'Bradesco',
          kind: 'checking',
          closingDayInCurrent: 0,
          createdAt: at,
        ),
        const v6.AccountsData(
          id: 2,
          name: 'Amazon',
          kind: 'creditCard',
          linkedAccountId: 1,
          closingDay: 22,
          closingDayInCurrent: 1,
          createdAt: at,
        ),
      ];
      final oldEntries = <v6.EntriesData>[
        const v6.EntriesData(
          id: 1,
          accountId: 2,
          type: 'expense',
          description: 'Mouse',
          amountCents: 12999,
          date: at,
          competence: 202511,
          createdAt: at,
        ),
        const v6.EntriesData(
          id: 2,
          accountId: 1,
          toAccountId: 2,
          type: 'billPayment',
          description: 'Pagamento fatura Amazon',
          amountCents: 12999,
          date: at,
          competence: 202511,
          createdAt: at,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 6,
        newVersion: 7,
        createOld: v6.DatabaseAtV6.new,
        createNew: v7.DatabaseAtV7.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.accounts, oldAccounts);
          batch.insertAll(oldDb.entries, oldEntries);
          batch.insertAll(oldDb.appSettings, [
            const v6.AppSettingsData(
              id: 1,
              monthStartDay: 27,
              themeMode: 2,
              textScale: 1.3,
              highContrast: 1,
            ),
          ]);
        },
        validateItems: (newDb) async {
          final accounts = await newDb.select(newDb.accounts).get();
          expect(accounts.map((a) => a.name), ['Bradesco', 'Amazon']);
          expect(accounts.last.closingDayInCurrent, 1, reason: 'a regra do cartão continua');

          final entries = await newDb.select(newDb.entries).get();
          expect(entries.map((e) => e.description), ['Mouse', 'Pagamento fatura Amazon']);
          expect(entries.every((e) => e.competence == 202511), isTrue);

          final settings = await newDb.select(newDb.appSettings).getSingle();
          expect(settings.monthStartDay, 27, reason: 'a configuração continua');
          expect(settings.textScale, 1.3);
          expect(settings.lastBackupAt, equals(null), reason: 'nunca fez backup');

          final indexes = await newDb
              .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
              .map((r) => r.read<String>('name'))
              .get();
          expect(indexes, containsAll(['entries_account_date', 'entries_to_account']));
        },
      );
    },
  );
}
