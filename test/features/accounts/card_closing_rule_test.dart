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
import 'package:izifnc/features/accounts/presentation/account_form_screen.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/entries/presentation/month_screen.dart';

/// A escolha do cartão para a compra feita no dia do fechamento: fatura atual
/// ou próxima. Padrão "atual" no cartão novo; cartão que já existia (migrado)
/// segue em "próxima".
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
  });

  late AppDatabase db;
  late AccountsRepository accounts;
  late int owner;

  // Mesma receita do widget_test.dart (streams síncronas e close com limite).
  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    accounts = AccountsRepository(db, EntriesRepository(db));
    owner = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> open(WidgetTester tester, String path) async {
    // O formulário do cartão é comprido: numa janela baixa o Salvar fica fora
    // da área visível e a lista nem o constrói.
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
    GoRouter.of(tester.element(find.byType(MonthScreen))).push(path);
    await tester.pumpAndSettle();
  }

  bool selectedIsCurrent(WidgetTester tester) =>
      tester.widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>)).selected.single;

  testWidgets('conta corrente não mostra a escolha (é só do cartão)', (tester) async {
    await open(tester, AccountFormScreen.newPath);

    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('cartão novo: a escolha aparece com "Fatura atual" marcada', (tester) async {
    await open(tester, AccountFormScreen.newPath);
    await tester.tap(find.text('Cartão'));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.text('Fatura atual'), findsOneWidget);
    expect(find.text('Próxima fatura'), findsOneWidget);
    expect(selectedIsCurrent(tester), isTrue);
    expect(find.textContaining('Itaú e Mercado Pago'), findsOneWidget, reason: 'ajuda com exemplos de bancos');
  });

  testWidgets('salvar um cartão novo guarda a escolha', (tester) async {
    await open(tester, AccountFormScreen.newPath);
    await tester.tap(find.text('Cartão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Nubank');
    await tester.enterText(find.widgetWithText(TextField, 'Dia do fechamento da fatura'), '20');
    await tester.tap(find.text('Próxima fatura'));
    await tester.pumpAndSettle();
    // A conta dona é obrigatória para cartão.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bradesco'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Consulta direta, não um Stream: dentro do testWidgets o relógio é falso e
    // um `.first` num stream do drift nunca completa (o teste travava aqui).
    final saved = (await db.select(db.accounts).get()).singleWhere((a) => a.name == 'Nubank');
    expect(saved.closingDayInCurrent, isFalse);
    expect(saved.closingDay, 20);
  });

  testWidgets('cartão que já existia (regra antiga) abre em "Próxima fatura"', (tester) async {
    final id = await accounts.create(
      name: 'Caixa',
      kind: AccountKind.creditCard,
      linkedAccountId: owner,
      closingDay: 26,
      closingDayInCurrent: false,
    );
    await open(tester, AccountFormScreen.editPath(id));

    expect(selectedIsCurrent(tester), isFalse);
  });

  testWidgets('trocar a escolha de um cartão existente e salvar recalcula o mês das compras do dia do fechamento', (
    tester,
  ) async {
    final id = await accounts.create(
      name: 'Caixa',
      kind: AccountKind.creditCard,
      linkedAccountId: owner,
      closingDay: 26,
      closingDayInCurrent: false,
    );
    final entries = EntriesRepository(db);
    final entryId = await entries.save(
      EntryDraft(
        accountId: id,
        type: EntryType.expense,
        description: 'Compra',
        amountCents: 1000,
        date: DateTime(2025, 11, 26),
      ),
    );
    expect((await entries.find(entryId))!.competence, 202512, reason: 'regra "próxima"');
    await open(tester, AccountFormScreen.editPath(id));

    await tester.tap(find.text('Fatura atual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect((await accounts.find(id))!.closingDayInCurrent, isTrue);
    expect((await entries.find(entryId))!.competence, 202511, reason: 'agora "atual"');
  });

  testWidgets('mexer só na escolha já conta como alteração não salva (pede para descartar ao voltar)', (
    tester,
  ) async {
    final id = await accounts.create(
      name: 'Caixa',
      kind: AccountKind.creditCard,
      linkedAccountId: owner,
      closingDay: 26,
      closingDayInCurrent: false,
    );
    await open(tester, AccountFormScreen.editPath(id));
    await tester.tap(find.text('Fatura atual'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voltar')); // o tooltip do app é pt-BR
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget, reason: 'pergunta se descarta');
  });
}
