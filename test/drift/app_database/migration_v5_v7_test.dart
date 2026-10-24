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
