import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/data/llm_slot.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';
import 'package:izifnc/features/entries/presentation/month_screen.dart';
import 'package:izifnc/features/import/presentation/import_providers.dart';
import 'package:izifnc/features/import/presentation/import_screen.dart';

import '../../support/real_fonts.dart';

/// Devolve onde ficam as tabelas da planilha de exemplo, como se a IA tivesse acertado.
class _KnownLocator implements LlmTableLocator {
  @override
  String get providerName => 'esperado';

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async => const TableLocations(
    despesasGerais: TableLocation(headerRow: 18, startCol: 1),
    entradaDeValor: TableLocation(headerRow: 18, startCol: 15),
  );
}

/// O caminho de escolher a aba (feat 0023, correção): a importação é aberta pelo
/// menu, que **troca** a tela; a tela anterior (com os providers de contas e do
/// dia de virada) some. Ler esses providers no meio do fluxo falhava com "The
/// provider accountsProvider was disposed during loading state".
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final accounts = AccountsRepository(db, EntriesRepository(db));
    final azul = await accounts.create(name: 'Azul', kind: AccountKind.checking);
    await accounts.create(name: 'Verde', kind: AccountKind.checking);
    await accounts.create(name: 'Roxo', kind: AccountKind.creditCard, linkedAccountId: azul, closingDay: 20);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> openImportFromMenu(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final bytes = File('docs/exemplo/espelho-do-real.xlsx').readAsBytesSync();
    final ai = MemoryAiSlotsStore()
      ..seed(AiSlot.primary, const LlmSlot(kind: LlmServiceKind.groq, apiKey: 'gsk_teste_1234'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          aiSlotsStoreProvider.overrideWithValue(ai),
          llmTableLocatorProvider.overrideWithValue(_KnownLocator()),
          importFilePickerProvider.overrideWithValue(() async => bytes),
          tourEnabledProvider.overrideWithValue(false),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Como o menu faz: `go` (a home sai da árvore).
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/importar');
    await tester.pumpAndSettle();
  }

  testWidgets('escolher o arquivo e depois a aba leva ao mapeamento, sem erro', (tester) async {
    await openImportFromMenu(tester);

    await tester.tap(find.text('Escolher arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Mes1'), findsOneWidget, reason: 'as abas da planilha');

    await tester.tap(find.text('Mes1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não consegui'), findsNothing, reason: 'nada de erro');
    expect(find.textContaining('disposed'), findsNothing);
    expect(find.textContaining('Para qual conta ou cartão vai cada um?'), findsOneWidget);
  });

  testWidgets('o fluxo inteiro (arquivo, aba, mapear, prévia, importar) grava os lançamentos, sem erro', (tester) async {
    await openImportFromMenu(tester);
    await tester.tap(find.text('Escolher arquivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes1'));
    await tester.pumpAndSettle();

    // Deixa de fora todos os pares e mapeia só o primeiro para a conta Azul.
    final skips = find.widgetWithText(ChoiceChip, 'Não importar');
    final total = tester.widgetList(skips).length;
    expect(total, greaterThan(0), reason: 'o mapeamento mostrou os pares da aba');
    for (var i = 0; i < total; i++) {
      await tester.ensureVisible(skips.at(i));
      await tester.pumpAndSettle();
      await tester.tap(skips.at(i));
      await tester.pumpAndSettle();
    }
    final azul = find.widgetWithText(ChoiceChip, 'Azul').first;
    await tester.ensureVisible(azul);
    await tester.pumpAndSettle();
    await tester.tap(azul);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não consegui'), findsNothing);

    // O botão da prévia: "Importar N lançamento(s)".
    final importButton = find.ancestor(
      of: find.textContaining(RegExp(r'^Importar \d+ lançamento')),
      matching: find.byType(FilledButton),
    );
    expect(importButton, findsOneWidget, reason: 'a prévia tem lançamentos para importar');
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Não foi possível'), findsNothing, reason: 'nada de erro ao gravar');
    expect(find.textContaining('disposed'), findsNothing);
    expect((await db.select(db.entries).get()).length, greaterThan(0), reason: 'os lançamentos foram gravados');

    // "Voltar para o mês": a importação foi aberta pelo menu (`go`), então não há
    // tela por baixo para desempilhar; o botão tem de levar à home.
    await tester.tap(find.text('Voltar para o mês'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthScreen), findsOneWidget, reason: 'o botão leva à home');
    expect(find.byType(ImportScreen), findsNothing);
  });
}
