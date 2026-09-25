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
import 'package:izifnc/core/widgets/tour_bubble.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/presentation/month_filters.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/presentation/import_providers.dart';

import '../support/real_fonts.dart';

/// O tour guiado (feat 0026): sete paradas, uma sequência só, andando de tela
/// em tela sozinho conforme a pessoa toca o botão de cada bolha. Começa
/// sozinho na primeira vez (sem conta ainda); "Pular o tour" ou "Concluir" no
/// fim marcam como visto; "Ver o tour de novo" em Configurações reinicia.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;
  late AccountsRepository accounts;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    accounts = AccountsRepository(db, EntriesRepository(db));
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // A importação lê a chave de IA; o Keystore não existe no teste.
          aiSlotsStoreProvider.overrideWithValue(MemoryAiSlotsStore()),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// O botão da bolha, não o botão real que ela destaca (que pode ter o
  /// mesmo texto — ex. "Cadastrar conta" nos dois, no primeiro passo).
  Finder bubbleButton(String label) => find.descendant(
    of: find.byType(TourBubble),
    matching: find.widgetWithText(FilledButton, label),
  );

  /// O pacote calcula de que lado cabe a bolha em mais de um frame fora do
  /// laço do `pumpAndSettle` — sem isto o teste esbarra numa bolha que ainda
  /// não terminou de aparecer.
  Future<void> waitForBubble(WidgetTester tester) async {
    // Não é só o tempo: o pacote encadeia alguns `Future`s para calcular a
    // posição da bolha, e cada um só resolve num `pump()` próprio — por isso
    // vários pumps, não um só mais longo.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Toca o botão da bolha atual e espera a próxima (mesma tela ou não)
  /// terminar de aparecer, pronta pra próxima asserção.
  Future<void> tapBubble(WidgetTester tester, String label) async {
    await waitForBubble(tester);
    await tester.tap(bubbleButton(label));
    await tester.pumpAndSettle();
    await waitForBubble(tester);
  }

  testWidgets('percorre as 7 paradas, cada uma na tela certa, até Concluir', (tester) async {
    await pumpApp(tester);

    // 1) Cadastrar conta — na home vazia, sem precisar navegar antes. O
    // pacote desenha o próprio "SKIP" num canto por padrão; já temos "Pular
    // o tour" na bolha, então esse extra deve ficar escondido (achado no
    // celular real: sobrava por cima do botão flutuante).
    await waitForBubble(tester);
    expect(find.text('1 de 7'), findsOneWidget);
    expect(find.text('SKIP'), findsNothing);
    await tester.tap(bubbleButton('Cadastrar conta'));
    await tester.pumpAndSettle();
    expect(find.text('Nova conta'), findsOneWidget, reason: 'a bolha navegou pro formulário');
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Bradesco');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // 2) Situação — mesma tela (home), avança sem navegar.
    await waitForBubble(tester);
    expect(find.text('2 de 7'), findsOneWidget);
    await tapBubble(tester, 'Próximo');

    // 3) Busca e filtros — ainda a home. A lupa e o filtro ficam sob o mesmo
    // alvo (achado no celular real: só o filtro era destacado, mas o texto
    // falava dos dois).
    expect(find.text('3 de 7'), findsOneWidget);
    final searchTarget = find.ancestor(
      of: find.byType(FilterButton),
      matching: find.byType(TourTarget),
    );
    expect(searchTarget, findsOneWidget);
    expect(
      find.descendant(of: searchTarget, matching: find.byIcon(Icons.search)),
      findsOneWidget,
      reason: 'a lupa deve estar no mesmo alvo do tour que o filtro',
    );
    await tapBubble(tester, 'Próximo');
    expect(find.text('Novo lançamento'), findsWidgets, reason: 'navegou pro formulário de lançamento');

    // 4) Grade de tipos — lançamento (menciona "Pagar fatura" no texto, sem
    // destacar o chip à parte — nenhum alvo aninhado dentro de outro). O
    // campo "Valor" não pode estar em foco: senão o teclado sobe por cima da
    // bolha (achado no celular real).
    expect(find.text('4 de 7'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Valor'),
      findsOneWidget,
      reason: 'a tela do lançamento carregou',
    );
    expect(
      tester.testTextInput.isVisible,
      isFalse,
      reason: '"Valor" não deve focar sozinho: o teclado cobriria a bolha do tour',
    );
    await tapBubble(tester, 'Próximo');
    expect(find.text('Importar planilha'), findsOneWidget, reason: 'navegou pra importação');

    // 5) Escolher arquivo — mostra mesmo com o botão desligado (sem chave de
    // IA configurada neste teste): senão o tour travaria aqui para sempre.
    expect(find.text('5 de 7'), findsOneWidget);
    await tapBubble(tester, 'Próximo');
    expect(find.text('Configurações'), findsWidgets, reason: 'navegou pra Configurações');

    // 6) Menu de Configurações.
    expect(find.text('6 de 7'), findsOneWidget);
    await tapBubble(tester, 'Próximo');
    expect(find.text('Dados'), findsOneWidget, reason: 'navegou pra Configurações › Dados');

    // 7) Backup — último passo, botão "Concluir".
    expect(find.text('7 de 7'), findsOneWidget);
    await tapBubble(tester, 'Concluir');

    expect(find.byType(TourBubble), findsNothing, reason: 'tour concluído, nenhuma bolha sobra');
  });

  testWidgets('"Pular o tour" no primeiro passo encerra tudo de uma vez', (tester) async {
    await pumpApp(tester);
    await waitForBubble(tester);

    await tester.tap(find.descendant(
      of: find.byType(TourBubble),
      matching: find.text('Pular o tour'),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(TourBubble), findsNothing);

    // Cadastrar a conta e visitar as outras telas não traz o tour de volta.
    await tester.tap(find.text('Cadastrar conta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Bradesco');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    await waitForBubble(tester);
    expect(find.byType(TourBubble), findsNothing);
  });

  testWidgets('"Ver o tour de novo" com conta já cadastrada pula direto pro 2º passo', (
    tester,
  ) async {
    await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    await pumpApp(tester);
    // Sem tour pendente ainda (a conta já existia ao abrir): confere o estado
    // inicial antes de ir a Configurações.
    await waitForBubble(tester);

    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/configuracoes/geral');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver o tour de novo'));
    await tester.pumpAndSettle();
    await waitForBubble(tester);

    // Pula o passo 0 (cadastrar conta — não existe mais alvo pra ele) e cai
    // direto no passo 1 (situação), que já existe porque há conta.
    expect(find.text('2 de 7'), findsOneWidget);
  });
}
