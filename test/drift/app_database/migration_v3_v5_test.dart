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
}
