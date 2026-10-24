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
}
