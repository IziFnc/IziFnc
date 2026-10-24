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
}
