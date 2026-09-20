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
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/data/llm_slot.dart';
import 'package:izifnc/features/import/presentation/import_providers.dart';

import '../../support/real_fonts.dart';

/// O primeiro passo da importação diz o que precisa antes (feat 0023): contas
/// cadastradas e chave de IA. Sem isso o botão de escolher o arquivo fica
/// desligado, em vez de a pessoa escolher arquivo e aba e só então esbarrar no erro.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;
  late AccountsRepository accounts;
  late MemoryAiSlotsStore ai;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    accounts = AccountsRepository(db, EntriesRepository(db));
    ai = MemoryAiSlotsStore();
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> openImport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          aiSlotsStoreProvider.overrideWithValue(ai),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/importar');
    await tester.pumpAndSettle();
  }

  Finder chooseFile() => find.widgetWithText(FilledButton, 'Escolher arquivo');
  bool enabled(WidgetTester tester) => tester.widget<FilledButton>(chooseFile()).onPressed != null;

  void seedAi() => ai.seed(AiSlot.primary, const LlmSlot(kind: LlmServiceKind.groq, apiKey: 'gsk_teste_1234'));

  testWidgets('sem contas e sem IA: os dois itens pendentes e o botão desligado', (tester) async {
    await openImport(tester);

    expect(find.text('Contas e cartões cadastrados'), findsOneWidget);
    expect(find.text('Chave de IA configurada'), findsOneWidget);
    expect(find.text('Cadastrar'), findsOneWidget);
    expect(find.text('Configurar'), findsOneWidget);
    expect(enabled(tester), isFalse);
    expect(find.text('Faça os itens pendentes acima para escolher o arquivo.'), findsOneWidget);
  });

  testWidgets('com contas mas sem IA: só a IA fica pendente e leva a Configurações', (tester) async {
    await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    await openImport(tester);

    expect(find.text('Cadastrar'), findsNothing);
    expect(find.text('Configurar'), findsOneWidget);
    expect(enabled(tester), isFalse);

    await tester.tap(find.text('Configurar'));
    await tester.pumpAndSettle();
    expect(find.text('Inteligência artificial'), findsWidgets);
  });

  testWidgets('com IA mas sem contas: só as contas ficam pendentes e levam a cadastrar', (tester) async {
    seedAi();
    await openImport(tester);

    expect(find.text('Configurar'), findsNothing);
    expect(find.text('Cadastrar'), findsOneWidget);
    expect(enabled(tester), isFalse);

    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova conta'), findsOneWidget);
  });

  testWidgets('tudo pronto: nada pendente e o botão liga', (tester) async {
    await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    seedAi();
    await openImport(tester);

    expect(find.text('Cadastrar'), findsNothing);
    expect(find.text('Configurar'), findsNothing);
    expect(enabled(tester), isTrue);
    expect(find.textContaining('Faça os itens pendentes'), findsNothing);
  });

  testWidgets('sempre lembra do saldo inicial e do formato esperado da planilha', (tester) async {
    await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    seedAi();
    await openImport(tester);

    expect(find.text('Ajuste o saldo inicial de cada conta'), findsOneWidget);
    expect(find.textContaining('Despesas Gerais'), findsOneWidget);
    expect(find.textContaining('Entrada de Valor'), findsOneWidget);
  });
}
