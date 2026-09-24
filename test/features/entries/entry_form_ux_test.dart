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
import 'package:izifnc/core/utils/formatters.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';

import '../../support/real_fonts.dart';

/// Formulário de lançamento (feat 0021, auditoria de UX): tipos em grade fixa,
/// "Salvar e novo" e excluir com desfazer.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;
  late EntriesRepository entries;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    final bradesco = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    await accounts.create(name: 'C6', kind: AccountKind.checking);
    await accounts.create(
      name: 'Amazon',
      kind: AccountKind.creditCard,
      linkedAccountId: bradesco,
      closingDay: 31,
    );
    await entries.adjustBalance(accountId: bradesco, target: 500000);
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
          tourEnabledProvider.overrideWithValue(false),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openNewEntry(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Novo lançamento'));
    await tester.pumpAndSettle();
  }

  /// Abre a edição **por cima** da home (como o toque na lista), para o pop ter
  /// para onde voltar.
  Future<void> openEdit(WidgetTester tester, int id) async {
    await pumpApp(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/lancamento/$id');
    await tester.pumpAndSettle();
  }

  Future<List<Entry>> savedExpenses() async => [
    for (final e in await db.select(db.entries).get())
      if (e.type == EntryType.expense) e,
  ];

  Finder typeChip(String label) => find.widgetWithText(ChoiceChip, label);

  group('tipos em grade fixa', () {
    testWidgets('cada tipo fica no mesmo lugar, qualquer que seja o escolhido', (tester) async {
      await openNewEntry(tester);
      final labels = ['Despesa', 'Entrada', 'Transferência', 'Pagar fatura'];
      Map<String, Offset> positions() => {for (final l in labels) l: tester.getTopLeft(typeChip(l))};

      final inicial = positions();
      for (final chosen in labels.skip(1)) {
        await tester.tap(typeChip(chosen));
        await tester.pumpAndSettle();
        expect(positions(), inicial, reason: 'ao escolher "$chosen" algum tipo mudou de lugar');
      }
    });

    testWidgets('em duas linhas de dois, alinhados à esquerda e à direita', (tester) async {
      await openNewEntry(tester);

      final despesa = tester.getRect(typeChip('Despesa'));
      final entrada = tester.getRect(typeChip('Entrada'));
      final transf = tester.getRect(typeChip('Transferência'));
      final fatura = tester.getRect(typeChip('Pagar fatura'));

      expect(despesa.top, entrada.top);
      expect(transf.top, fatura.top);
      expect(transf.top, greaterThan(despesa.bottom));
      expect(despesa.left, transf.left);
      expect(entrada.left, fatura.left);
      expect(despesa.width, entrada.width, reason: 'mesma largura');
    });
  });

  group('Salvar e novo', () {
    testWidgets('grava, limpa valor e descrição e fica no formulário para o próximo', (tester) async {
      await openNewEntry(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bradesco'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '1000');
      await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Café');
      await tester.pump();

      await tester.tap(find.text('Salvar e novo'));
      await tester.pumpAndSettle();

      expect((await savedExpenses()).map((e) => e.description), ['Café']);
      expect(find.text('Novo lançamento'), findsOneWidget, reason: 'continua no formulário');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Valor')).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Descrição')).controller!.text, isEmpty);
      expect(find.text('Salvo: Café · ${Formatters.money(1000)}'), findsOneWidget, reason: 'confirmação no rodapé');
      expect(find.byType(SnackBar), findsNothing, reason: 'um SnackBar taparia o botão');

      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '200');
      await tester.pump();
      expect(find.textContaining('Salvo:'), findsNothing, reason: 'some quando começa o próximo');
      // A conta escolhida continua escolhida (é o que costuma se repetir).
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Bradesco')).selected, isTrue);
    });

    testWidgets('dá para lançar vários seguidos', (tester) async {
      await openNewEntry(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bradesco'));
      await tester.pumpAndSettle();

      for (final (cents, name) in [('500', 'Pão'), ('1200', 'Táxi'), ('9900', 'Livro')]) {
        await tester.enterText(find.widgetWithText(TextField, 'Valor'), cents);
        await tester.enterText(find.widgetWithText(TextField, 'Descrição'), name);
        await tester.pump();
        await tester.tap(find.text('Salvar e novo'));
        await tester.pumpAndSettle();
      }

      expect((await savedExpenses()).map((e) => e.description).toSet(), {'Pão', 'Táxi', 'Livro'});
    });

    testWidgets('sem valor não grava e mostra o erro, como o Salvar', (tester) async {
      await openNewEntry(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bradesco'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Sem valor');
      await tester.pump();

      await tester.tap(find.text('Salvar e novo'));
      await tester.pumpAndSettle();

      expect(await savedExpenses(), isEmpty);
      expect(find.text('Informe o valor'), findsOneWidget);
    });

    testWidgets('o Salvar de sempre continua fechando o formulário', (tester) async {
      await openNewEntry(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bradesco'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '700');
      await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Bala');
      await tester.pump();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Novo lançamento'), findsNothing);
      expect((await savedExpenses()).map((e) => e.description), ['Bala']);
    });

    testWidgets('editar um lançamento não oferece "Salvar e novo"', (tester) async {
      final id = await entries.save(
        EntryDraft(
          accountId: (await db.select(db.accounts).get()).first.id,
          type: EntryType.expense,
          description: 'Editável',
          amountCents: 1000,
          date: DateTime.now(),
        ),
      );
      await openEdit(tester, id);

      expect(find.text('Editar lançamento'), findsOneWidget);
      expect(find.text('Salvar e novo'), findsNothing);
    });
  });

  group('excluir com desfazer', () {
    Future<int> saveOne() async => entries.save(
      EntryDraft(
        accountId: (await db.select(db.accounts).get()).first.id,
        type: EntryType.expense,
        description: 'Para excluir',
        amountCents: 3300,
        date: DateTime.now(),
      ),
    );

    testWidgets('exclui na hora, sem diálogo, e avisa com a opção Desfazer', (tester) async {
      final id = await saveOne();
      await openEdit(tester, id);

      await tester.tap(find.byTooltip('Excluir lançamento'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir lançamento?'), findsNothing, reason: 'sem "tem certeza?"');
      expect(await entries.find(id), equals(null));
      expect(find.text('Lançamento excluído.'), findsOneWidget);
      expect(find.text('Desfazer'), findsOneWidget);
    });

    testWidgets('Desfazer devolve o lançamento como era', (tester) async {
      final id = await saveOne();
      final before = (await entries.find(id))!;
      await openEdit(tester, id);
      await tester.tap(find.byTooltip('Excluir lançamento'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(await entries.find(id), before);
    });
  });
}
