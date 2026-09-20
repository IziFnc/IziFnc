import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/settings/data/settings_repository.dart';

import '../../support/real_fonts.dart';

/// As duas faixas da home (feat 0022): "Primeiros passos" para quem ainda não
/// lançou nada e o lembrete de backup vencido.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;
  late EntriesRepository entries;
  late AccountsRepository accounts;
  late SettingsRepository settings;
  late int conta;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    entries = EntriesRepository(db);
    accounts = AccountsRepository(db, entries);
    settings = SettingsRepository(db, entries);
    conta = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> addEntries(int n) async {
    for (var i = 0; i < n; i++) {
      await entries.save(
        EntryDraft(
          accountId: conta,
          type: EntryType.expense,
          description: 'Gasto $i',
          amountCents: 100 + i,
          date: DateTime.now(),
        ),
      );
    }
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Primeiros passos', () {
    testWidgets('conta cadastrada e nenhum lançamento: mostra o guia no lugar da lista vazia', (tester) async {
      await pumpHome(tester);

      expect(find.text('Primeiros passos'), findsOneWidget);
      expect(find.text('Ajustar o saldo'), findsOneWidget);
      expect(find.text('Cadastrar um cartão'), findsOneWidget);
      expect(find.text('Importar a sua planilha'), findsOneWidget);
      expect(find.text('Lançar o primeiro gasto'), findsOneWidget);
      expect(find.textContaining('Nenhum lançamento em'), findsNothing);
    });

    testWidgets('quem já tem cartão não recebe o passo "Cadastrar um cartão"', (tester) async {
      await accounts.create(name: 'Amazon', kind: AccountKind.creditCard, linkedAccountId: conta, closingDay: 22);
      await pumpHome(tester);

      expect(find.text('Primeiros passos'), findsOneWidget);
      expect(find.text('Cadastrar um cartão'), findsNothing);
    });

    testWidgets('some no primeiro lançamento (e a lista do mês vazio volta ao texto normal em outro mês)', (tester) async {
      await addEntries(1);
      await pumpHome(tester);

      expect(find.text('Primeiros passos'), findsNothing);
      expect(find.text('Gasto 0'), findsOneWidget);
    });

    testWidgets('"Lançar o primeiro gasto" abre o formulário', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Lançar o primeiro gasto'));
      await tester.pumpAndSettle();

      expect(find.text('Novo lançamento'), findsOneWidget);
    });
  });

  group('aviso de backup', () {
    const nunca = 'Você ainda não salvou um backup dos seus dados.';

    testWidgets('nunca fez e já tem uma base de lançamentos (10 ou mais): avisa', (tester) async {
      await addEntries(10);
      await pumpHome(tester);

      expect(find.text(nunca), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('nunca fez, mas ainda são poucos lançamentos: não incomoda', (tester) async {
      await addEntries(9);
      await pumpHome(tester);

      expect(find.text(nunca), findsNothing);
    });

    testWidgets('backup recente: não avisa', (tester) async {
      await addEntries(12);
      await settings.markBackup(DateTime.now().subtract(const Duration(days: 3)));
      await pumpHome(tester);

      expect(find.textContaining('backup'), findsNothing);
    });

    testWidgets('backup de mais de 30 dias: avisa quantos dias faz', (tester) async {
      await addEntries(2);
      await settings.markBackup(DateTime.now().subtract(const Duration(days: 45)));
      await pumpHome(tester);

      expect(find.text('Faz 45 dias que você não salva um backup.'), findsOneWidget);
    });

    testWidgets('dispensar esconde a faixa', (tester) async {
      await addEntries(10);
      await pumpHome(tester);
      expect(find.text(nunca), findsOneWidget);

      await tester.tap(find.byTooltip('Dispensar'));
      await tester.pumpAndSettle();

      expect(find.text(nunca), findsNothing);
    });

    testWidgets('"Salvar" leva a Configurações › Dados', (tester) async {
      await addEntries(10);
      await pumpHome(tester);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Dados'), findsWidgets);
      expect(find.text('Salvar backup'), findsOneWidget);
    });
  });
}
