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

import 'support/menu.dart';
import 'support/real_fonts.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;

  setUp(() {
    // closeStreamsSynchronously: sem isso o drift fecha as streams num Timer,
    // que o relógio falso do testWidgets nunca dispara ("A Timer is still
    // pending"). Receita da documentação de testes do drift.
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  // Fechar aqui, no tearDown normal, e não com addTearDown dentro do
  // testWidgets: lá dentro o tempo é falso e o close() espera para sempre.
  //
  // O timeout é de propósito: se um teste falha no meio do fluxo, alguma
  // operação do drift iniciada no tempo falso fica sem terminar e o close()
  // esperaria por ela para sempre, travando a suíte inteira. Com o limite, o
  // teste falha rápido e mostra o erro de verdade.
  tearDown(
    () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
  );

  /// Sobe o app inteiro com o banco em memória no lugar do real.
  Future<AppDatabase> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('sem conta, a home pede para cadastrar e esconde o +', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Cadastre sua primeira conta'), findsOneWidget);
    expect(find.byTooltip('Novo lançamento'), findsNothing);
  });

  testWidgets('cadastrar a primeira conta libera o lançamento', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Cadastrar conta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Bradesco');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Cadastre sua primeira conta'), findsNothing);
    expect(find.byTooltip('Novo lançamento'), findsOneWidget);
  });

  testWidgets('com o teclado aberto, o Salvar continua visível acima dele', (
    tester,
  ) async {
    await pumpApp(tester);
    final entries = EntriesRepository(db);
    await AccountsRepository(
      db,
      entries,
    ).create(name: 'Bradesco', kind: AccountKind.checking);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Novo lançamento'));
    await tester.pumpAndSettle();

    // Simula um teclado de 300px (em pixels físicos, por isso o * dpr).
    final dpr = tester.view.devicePixelRatio;
    tester.view.viewInsets = FakeViewPadding(bottom: 300 * dpr);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final screenHeight = tester.view.physicalSize.height / dpr;
    final save = tester.getRect(find.text('Salvar'));
    expect(
      save.bottom,
      lessThanOrEqualTo(screenHeight - 300),
      reason: 'Salvar atrás do teclado',
    );
    expect(find.textContaining('Vai para:'), findsOneWidget);
  });

  testWidgets('transferência só oferece contas, nunca cartões', (tester) async {
    await pumpApp(tester);
    final entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    final bradesco = await accounts.create(
      name: 'Bradesco',
      kind: AccountKind.checking,
    );
    await accounts.create(name: 'C6', kind: AccountKind.checking);
    await accounts.create(
      name: 'Amazon',
      kind: AccountKind.creditCard,
      closingDay: 22,
      linkedAccountId: bradesco,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Novo lançamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transferência'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Amazon'),
      findsNothing,
      reason: 'cartão fora de De e Para',
    );
    expect(find.widgetWithText(ChoiceChip, 'C6'), findsWidgets);
  });

  testWidgets(
    'pagar a fatura move o saldo e zera o cartão, sem mexer nos totais',
    (tester) async {
      // O formulário de pagamento ficou mais comprido (campo de juros): numa
      // janela baixa a descrição sugerida fica fora da área construída.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester);
      final entries = EntriesRepository(db);
      final accounts = AccountsRepository(db, entries);
      final bradesco = await accounts.create(
        name: 'Bradesco',
        kind: AccountKind.checking,
      );
      final amazon = await accounts.create(
        name: 'Amazon',
        kind: AccountKind.creditCard,
        closingDay: 22,
        linkedAccountId: bradesco, // o Amazon é do Bradesco
      );
      await entries.adjustBalance(accountId: bradesco, target: 50000);
      await entries.save(
        EntryDraft(
          accountId: amazon,
          type: EntryType.expense,
          description: 'Mouse',
          amountCents: 5000,
          date: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      // O cartão de situação mostra de relance quanto há em conta e a fatura aberta.
      expect(find.text('Em conta'), findsOneWidget);
      expect(find.text(Formatters.money(50000)), findsOneWidget, reason: 'o total em conta');
      expect(find.text('Faturas abertas'), findsOneWidget, reason: 'o cartão Amazon tem R\$ 50,00 em aberto');

      await tester.tap(find.byTooltip('Novo lançamento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '5000');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pagar fatura'));
      await tester.pumpAndSettle();
      // O chip do cartão mostra quanto está em aberto.
      await tester.tap(
        find.widgetWithText(
          ChoiceChip,
          'Amazon · ${Formatters.money(5000)} em aberto',
        ),
      );
      await tester.pumpAndSettle();
      // "Sai de" já vem com a conta dona do cartão, e a descrição é sugerida.
      final saiDe = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Bradesco'),
      );
      expect(saiDe.selected, isTrue, reason: 'conta dona pré-selecionada');
      expect(find.text('Pagamento fatura Amazon'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        find.text(Formatters.money(45000)),
        findsOneWidget,
        reason: 'saldo do Bradesco',
      );
      expect(
        find.text('Faturas abertas'),
        findsNothing,
        reason: 'cartão quitado sai do cartão de situação',
      );
      expect(find.textContaining('Bradesco → fatura Amazon'), findsOneWidget);
      // Totais do mês: o Mouse continua como gasto (do cartão); o pagamento da
      // fatura não é gasto novo.
      expect(find.textContaining('Gastou ${Formatters.money(5000)}'), findsOneWidget);
    },
  );

  group('ajustar saldo só ao salvar (feat 0005)', () {
    Future<(EntriesRepository, int)> openAccount(WidgetTester tester) async {
      await pumpApp(tester);
      final entries = EntriesRepository(db);
      final id = await AccountsRepository(
        db,
        entries,
      ).create(name: 'Bradesco', kind: AccountKind.checking);
      await tester.pumpAndSettle();
      // A conta se abre por Contas e cartões (no menu).
      await goViaMenu(tester, 'Contas e cartões');
      await tester.tap(find.text('Bradesco'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustar saldo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Saldo no banco'),
        '50000',
      );
      await tester.tap(find.text('Ajustar'));
      await tester.pumpAndSettle();
      return (entries, id);
    }

    testWidgets('o Ajustar do diálogo não grava nada', (tester) async {
      final (entries, id) = await openAccount(tester);

      expect(
        find.text('→ ${Formatters.money(50000)} ao salvar'),
        findsOneWidget,
      );
      expect(
        await entries.countForAccount(id),
        0,
        reason: 'nada gravado antes do Salvar',
      );
    });

    testWidgets('sair sem salvar pergunta e descarta', (tester) async {
      final (entries, id) = await openAccount(tester);

      // O botão voltar do Android: passa pelo PopScope, como no celular.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Contas e cartões'),
        findsOneWidget,
        reason: 'voltou para a lista de onde a conta foi aberta',
      );
      expect(await entries.countForAccount(id), 0);
    });

    testWidgets('salvar grava o ajuste e avisa', (tester) async {
      final (entries, id) = await openAccount(tester);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Descartar alterações?'),
        findsNothing,
        reason: 'Salvar não pergunta',
      );
      expect(find.textContaining('Conta salva. Ajuste de +'), findsOneWidget);
      expect(await entries.balanceOf(id), 50000);
    });
  });

  testWidgets('lançar uma despesa mostra ela na lista e no total do mês', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    final entries = EntriesRepository(db);
    await AccountsRepository(
      db,
      entries,
    ).create(name: 'Bradesco', kind: AccountKind.checking);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Novo lançamento'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '1234');
    await tester.enterText(
      find.widgetWithText(TextField, 'Descrição'),
      'Mercado',
    );
    await tester.pump();
    // Conta única vem pré-selecionada; o aviso de competência aparece.
    expect(find.textContaining('Vai para:'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Mercado'), findsOneWidget);
    // Na linha do lançamento e no "Gastou" do cartão de situação. Via Formatters e
    // não literal: o separador depois do R$ é NBSP, fácil de errar à mão.
    expect(find.text(Formatters.money(1234)), findsOneWidget);
    expect(find.text('Entrou ${Formatters.money(0)} · Gastou ${Formatters.money(1234)}'), findsOneWidget);
  });
}
