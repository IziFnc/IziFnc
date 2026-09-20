import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/core/utils/formatters.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';

import '../../support/real_fonts.dart';

/// Filtros da lista do mês (feat 0015) na home compacta (feat 0022): a busca é a
/// lupa da barra, o tipo mora na folha "Filtrar e ordenar" e a situação de
/// relance é o cartão do topo. Os totais e os saldos NÃO mudam com o filtro: ele
/// só decide o que a lista mostra.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    final entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    final bradesco = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    // Fecha no dia 31: em qualquer mês, hoje ainda é da fatura atual.
    final amazon = await accounts.create(
      name: 'Amazon',
      kind: AccountKind.creditCard,
      linkedAccountId: bradesco,
      closingDay: 31,
    );
    Future<void> add(int account, EntryType type, String description, int cents, {String? note}) =>
        entries.save(
          EntryDraft(
            accountId: account,
            type: type,
            description: description,
            amountCents: cents,
            date: DateTime.now(),
            note: note,
          ),
        );
    await add(bradesco, EntryType.expense, 'Mercado', 5000, note: 'compra do mês');
    await add(bradesco, EntryType.income, 'Salário', 500000);
    await add(amazon, EntryType.expense, 'Mouse', 12999);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> pumpHome(WidgetTester tester) async {
    // A lista fica abaixo do topo: numa janela baixa ela nem seria construída.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String description) => find.text(description);

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Filtrar e ordenar'));
    await tester.pumpAndSettle();
  }

  Future<void> closeFilters(WidgetTester tester) async {
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
  }

  /// Escolhe um tipo na folha de filtros e a fecha.
  Future<void> pickKind(WidgetTester tester, String label) async {
    await openFilters(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pumpAndSettle();
    await closeFilters(tester);
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
  }

  testWidgets('sem filtro: a lista mostra tudo e não há aviso de "mostrando"', (tester) async {
    await pumpHome(tester);

    for (final d in ['Mercado', 'Salário', 'Mouse']) {
      expect(tile(d), findsOneWidget, reason: d);
    }
    expect(find.textContaining('Mostrando'), findsNothing);
    expect(find.byTooltip('Filtrar e ordenar'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse, reason: 'sem número no botão');
  });

  testWidgets('a home não traz mais busca nem chips de tipo fixos acima da lista', (tester) async {
    await pumpHome(tester);

    expect(find.byType(TextField), findsNothing, reason: 'a busca é a lupa da barra');
    expect(find.widgetWithText(ChoiceChip, 'Despesas'), findsNothing, reason: 'o tipo fica na folha de filtros');
  });

  testWidgets('tipo "Despesas" pela folha esconde a entrada, avisa quantos e não mexe nos totais', (tester) async {
    await pumpHome(tester);
    expect(find.textContaining('Entrou ${Formatters.money(500000)}'), findsOneWidget);

    await pickKind(tester, 'Despesas');

    expect(tile('Salário'), findsNothing);
    expect(tile('Mercado'), findsOneWidget);
    expect(tile('Mouse'), findsOneWidget);
    expect(find.text('Mostrando 2 de 3 lançamento(s)'), findsOneWidget);
    expect(
      find.textContaining('Entrou ${Formatters.money(500000)}'),
      findsOneWidget,
      reason: 'o total do mês continua no cartão: filtrar só esconde a linha',
    );
  });

  testWidgets('busca (lupa) acha pela descrição e pela observação; "Limpar filtros" volta tudo', (tester) async {
    await pumpHome(tester);
    await openSearch(tester);
    final search = find.widgetWithText(TextField, 'Buscar lançamentos');

    await tester.enterText(search, 'mou');
    await tester.pumpAndSettle();
    expect(tile('Mouse'), findsOneWidget);
    expect(tile('Mercado'), findsNothing);

    await tester.enterText(search, 'do mês'); // está na observação do Mercado
    await tester.pumpAndSettle();
    expect(tile('Mercado'), findsOneWidget);
    expect(tile('Mouse'), findsNothing);

    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(tile('Mouse'), findsOneWidget);
    expect(tile('Salário'), findsOneWidget);
    expect(tester.widget<TextField>(search).controller!.text, isEmpty, reason: 'o campo acompanha');
  });

  testWidgets('fechar a busca limpa o texto e a lista volta inteira', (tester) async {
    await pumpHome(tester);
    await openSearch(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Buscar lançamentos'), 'mou');
    await tester.pumpAndSettle();
    expect(tile('Mercado'), findsNothing);

    await tester.tap(find.byTooltip('Fechar busca'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(tile('Mercado'), findsOneWidget);
    expect(find.byTooltip('Buscar'), findsOneWidget, reason: 'a lupa volta');
  });

  testWidgets('sem resultado: diz que nenhum lançamento combina e oferece limpar', (tester) async {
    await pumpHome(tester);
    await openSearch(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Buscar lançamentos'), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Nenhum lançamento com esses filtros.'), findsOneWidget);
    expect(find.text('Mostrando 0 de 3 lançamento(s)'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
  });

  testWidgets('filtrar por cartão pela folha, com o número no botão', (tester) async {
    await pumpHome(tester);
    await openFilters(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Amazon · cartão do Bradesco'));
    await tester.pumpAndSettle();
    await closeFilters(tester);

    expect(tile('Mouse'), findsOneWidget);
    expect(tile('Mercado'), findsNothing);
    expect(tile('Salário'), findsNothing);
    expect(find.text('Mostrando 1 de 3 lançamento(s)'), findsOneWidget);
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);
  });

  testWidgets('ordenar por valor põe o maior primeiro, sem esconder nada', (tester) async {
    await pumpHome(tester);
    double y(String d) => tester.getTopLeft(tile(d)).dy;
    expect(y('Salário') > y('Mercado') || y('Salário') > y('Mouse'), isTrue, reason: 'antes: ordem por data, o salário não é o primeiro');

    await openFilters(tester);
    await tester.tap(find.text('Valor'));
    await tester.pumpAndSettle();
    await closeFilters(tester);

    expect(y('Salário') < y('Mouse'), isTrue);
    expect(y('Mouse') < y('Mercado'), isTrue);
    expect(find.textContaining('Mostrando'), findsNothing, reason: 'ordenar não esconde: sem aviso');
  });

  testWidgets('trocar de mês zera os filtros', (tester) async {
    await pumpHome(tester);
    await pickKind(tester, 'Despesas');
    expect(find.text('Mostrando 2 de 3 lançamento(s)'), findsOneWidget);

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mostrando'), findsNothing);
    expect(tile('Salário'), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  group('cartão de situação (topo enxuto)', () {
    testWidgets('mostra em conta, faturas abertas e o que entrou e gastou, sem detalhes', (tester) async {
      await pumpHome(tester);

      expect(find.text('Em conta'), findsOneWidget);
      expect(find.text('Faturas abertas'), findsOneWidget, reason: 'a fatura em aberto já aparece de relance');
      expect(
        find.text('Entrou ${Formatters.money(500000)} · Gastou ${Formatters.money(5000 + 12999)}'),
        findsOneWidget,
      );
      expect(find.text('Bradesco'), findsNothing, reason: 'o detalhe por conta fica na folha');
      expect(find.text('Situação de ${_monthLabel()}'), findsNothing);
    });

    testWidgets('tocar abre a folha com cada conta, cada fatura e o resumo do mês', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Em conta'));
      await tester.pumpAndSettle();

      expect(find.text('Situação de ${_monthLabel()}'), findsOneWidget);
      expect(find.text('Contas (saldo de hoje)'), findsOneWidget);
      expect(find.text('Bradesco'), findsOneWidget);
      expect(find.text('Faturas abertas'), findsNWidgets(2), reason: 'o rótulo do cartão e o título da seção');
      expect(find.text('Cartão Amazon'), findsOneWidget);
      expect(find.text('Entradas'), findsOneWidget);
      expect(find.text('Gastos no débito'), findsOneWidget);
      expect(find.text('Gastos no cartão Amazon'), findsOneWidget);
    });

    testWidgets('tocar numa conta da folha filtra a lista por ela e fecha a folha', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Em conta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bradesco'));
      await tester.pumpAndSettle();

      expect(find.text('Situação de ${_monthLabel()}'), findsNothing, reason: 'a folha fechou');
      expect(tile('Mouse'), findsNothing, reason: 'o cartão Amazon saiu da lista');
      expect(tile('Mercado'), findsOneWidget);
      expect(find.text('Mostrando 2 de 3 lançamento(s)'), findsOneWidget);
    });

    testWidgets('as linhas da folha têm ao menos 48 dp de altura (alvo de toque)', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Em conta'));
      await tester.pumpAndSettle();

      final row = find.ancestor(of: find.text('Bradesco'), matching: find.byType(ListTile)).first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    });
  });
}

/// "setembro de 2026" (o mês de hoje), como a folha o escreve.
String _monthLabel() => Formatters.monthYear(DateTime.now());
