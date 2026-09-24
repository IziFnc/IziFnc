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
import 'package:izifnc/core/widgets/app_drawer.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/accounts/presentation/accounts_screen.dart';
import 'package:izifnc/features/entries/presentation/month_screen.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/presentation/import_providers.dart';
import 'package:izifnc/features/import/presentation/import_screen.dart';
import 'package:izifnc/features/settings/presentation/settings_screen.dart';

import '../support/menu.dart';
import '../support/real_fonts.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;

  // Mesma receita do widget_test.dart: streams fechadas de forma síncrona e
  // close() com limite, para o relógio falso não travar a suíte.
  setUp(() {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // A importação lê a chave de IA; o Keystore não existe no teste.
          aiSlotsStoreProvider.overrideWithValue(MemoryAiSlotsStore()),
          tourEnabledProvider.overrideWithValue(false),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDrawer(WidgetTester tester) => openMenu(tester);

  Future<void> goTo(WidgetTester tester, String label) async {
    await openMenu(tester);
    await tester.tap(menuItem(label));
    await tester.pumpAndSettle();
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationDrawer>(find.byType(NavigationDrawer)).selectedIndex!;

  testWidgets('a barra da home perde os três ícones e ganha o botão do menu', (tester) async {
    await pumpApp(tester);

    expect(find.byType(DrawerButton), findsOneWidget);
    expect(find.byTooltip('Importar planilha'), findsNothing);
    expect(find.byTooltip('Contas e cartões'), findsNothing);
    expect(find.byTooltip('Configurações'), findsNothing);
  });

  testWidgets('o menu lista os quatro destinos, com Início marcado na home', (tester) async {
    await pumpApp(tester);
    await openDrawer(tester);

    final drawer = find.byType(NavigationDrawer);
    for (final label in ['Início', 'Contas e cartões', 'Importar planilha', 'Configurações']) {
      expect(find.descendant(of: drawer, matching: find.text(label)), findsOneWidget, reason: label);
    }
    expect(find.descendant(of: drawer, matching: find.text('IziFnc')), findsOneWidget);
    expect(selectedIndex(tester), 0);
  });

  testWidgets('Contas e cartões abre a tela, sem pilha, e o item fica marcado', (tester) async {
    await pumpApp(tester);
    await goTo(tester, 'Contas e cartões');

    expect(find.byType(AccountsScreen), findsOneWidget);
    expect(GoRouter.of(tester.element(find.byType(AccountsScreen))).canPop(), isFalse,
        reason: 'destino de topo troca a tela: voltar sai do app em vez de empilhar');

    await openDrawer(tester);
    expect(selectedIndex(tester), 1);
  });

  testWidgets('Configurações abre a tela de seções e o item fica marcado', (tester) async {
    await pumpApp(tester);
    await goTo(tester, 'Configurações');

    expect(find.byType(SettingsScreen), findsOneWidget);
    await openDrawer(tester);
    expect(selectedIndex(tester), 3);
  });

  testWidgets('Início volta para a home', (tester) async {
    await pumpApp(tester);
    await goTo(tester, 'Contas e cartões');
    await goTo(tester, 'Início');

    expect(find.byType(MonthScreen), findsOneWidget);
    expect(find.byType(AccountsScreen), findsNothing);
  });

  testWidgets('tocar no item da tela em que já estou só fecha o menu', (tester) async {
    await pumpApp(tester);
    await goTo(tester, 'Início');

    expect(find.byType(MonthScreen), findsOneWidget);
    expect(find.byType(NavigationDrawer), findsNothing, reason: 'o menu fechou');
  });

  testWidgets('Importar planilha é um destino do menu: tem o botão do menu, não a seta de voltar', (tester) async {
    await pumpApp(tester);
    await goTo(tester, 'Importar planilha');

    expect(find.byType(ImportScreen), findsOneWidget);
    expect(find.byType(DrawerButton), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    await openMenu(tester);
    expect(selectedIndex(tester), AppDestination.importSheet.index, reason: 'o item fica marcado no menu');
  });

  testWidgets('abrir a importação a partir de Contas e cartões não deixa uma seta que volta para lá', (tester) async {
    await pumpApp(tester);
    await goTo(tester, 'Contas e cartões');
    await goTo(tester, 'Importar planilha');

    expect(find.byType(ImportScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing, reason: 'sem seta para "voltar" a Contas e cartões');
    expect(find.byType(DrawerButton), findsOneWidget);

    // Do menu dá para ir a qualquer destino.
    await goTo(tester, 'Início');
    expect(find.byType(MonthScreen), findsOneWidget);
  });
}
