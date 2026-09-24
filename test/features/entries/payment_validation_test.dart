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
import 'package:izifnc/features/entries/presentation/entry_form_screen.dart';
import 'package:izifnc/features/entries/presentation/month_screen.dart';

/// As regras de dinheiro do formulário manual: uma conta não transfere o que não
/// tem, e uma fatura não recebe mais do que deve. A importação não passa por
/// aqui (ver o último teste).
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
  });

  late AppDatabase db;
  late EntriesRepository entries;
  late int bradesco;
  late int c6;
  late int amazon;

  // Mesma receita do widget_test.dart (streams síncronas e close com limite).
  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    bradesco = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    c6 = await accounts.create(name: 'C6', kind: AccountKind.checking);
    amazon = await accounts.create(
      name: 'Amazon',
      kind: AccountKind.creditCard,
      closingDay: 22,
      linkedAccountId: bradesco,
    );
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> pumpApp(WidgetTester tester) async {
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

  Future<void> openNew(WidgetTester tester, String cents) async {
    await tester.tap(find.byTooltip('Novo lançamento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), cents);
  }

  /// Bradesco → C6. Bradesco aparece em "De" (primeiro) e C6 em "Para" (último).
  Future<void> fillTransfer(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transferência'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bradesco').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'C6').last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
  }

  Future<int> saveTransfer(int cents) => entries.save(
    EntryDraft(
      accountId: bradesco,
      toAccountId: c6,
      type: EntryType.transfer,
      description: 'Transferência',
      amountCents: cents,
      date: DateTime.now(),
    ),
  );

  Future<void> buy(int cents) => entries.save(
    EntryDraft(
      accountId: amazon,
      type: EntryType.expense,
      description: 'Mouse',
      amountCents: cents,
      date: DateTime.now(),
    ),
  );

  group('transferência', () {
    testWidgets('acima do saldo é bloqueada, com o motivo no campo do valor', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 10000);
      await pumpApp(tester);
      await openNew(tester, '15000');
      await fillTransfer(tester);
      await save(tester);

      expect(find.textContaining('Saldo insuficiente'), findsOneWidget);
      expect(find.byType(EntryFormScreen), findsOneWidget, reason: 'continua no formulário');
      expect(await entries.balanceOf(bradesco), 10000, reason: 'nada foi gravado');
      expect(await entries.balanceOf(c6), 0);
    });

    testWidgets('exatamente o saldo é permitida', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 10000);
      await pumpApp(tester);
      await openNew(tester, '10000');
      await fillTransfer(tester);
      await save(tester);

      expect(find.byType(EntryFormScreen), findsNothing);
      expect(await entries.balanceOf(bradesco), 0);
      expect(await entries.balanceOf(c6), 10000);
    });

    testWidgets('corrigir o valor limpa o aviso e deixa salvar', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 10000);
      await pumpApp(tester);
      await openNew(tester, '15000');
      await fillTransfer(tester);
      await save(tester);
      expect(find.textContaining('Saldo insuficiente'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '9000');
      await tester.pump();
      expect(find.textContaining('Saldo insuficiente'), findsNothing, reason: 'mudou o valor: aviso some');

      await save(tester);
      expect(await entries.balanceOf(bradesco), 1000);
    });

    testWidgets('editar: o valor que a própria transferência já gastou volta a estar disponível', (
      tester,
    ) async {
      await entries.adjustBalance(accountId: bradesco, target: 10000);
      final id = await saveTransfer(5000); // sobra 5000 no Bradesco
      await pumpApp(tester);
      GoRouter.of(tester.element(find.byType(MonthScreen))).push(EntryFormScreen.editPath(id));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '10000');
      await save(tester);

      expect(find.byType(EntryFormScreen), findsNothing, reason: '10000 cabe: 5000 livres + 5000 desta transferência');
      expect(await entries.balanceOf(bradesco), 0);
    });

    testWidgets('editar: um centavo além do que existia é bloqueado', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 10000);
      final id = await saveTransfer(5000);
      await pumpApp(tester);
      GoRouter.of(tester.element(find.byType(MonthScreen))).push(EntryFormScreen.editPath(id));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '10001');
      await save(tester);

      expect(find.textContaining('Saldo insuficiente'), findsOneWidget);
      expect(await entries.balanceOf(bradesco), 5000, reason: 'a transferência original ficou como estava');
    });
  });

  group('pagar fatura', () {
    /// Rótulo do chip do cartão quando ele deve [open] centavos.
    String cardLabel(int open) => 'Amazon · ${Formatters.money(open)} em aberto';

    Future<void> fillBill(WidgetTester tester, String cardLabel) async {
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pagar fatura'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, cardLabel));
      await tester.pumpAndSettle();
    }

    testWidgets('acima do que está em aberto é bloqueado', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openNew(tester, '6000');
      await fillBill(tester, cardLabel(5000));
      await save(tester);

      expect(find.textContaining('Acima do que está em aberto'), findsOneWidget);
      expect(find.byType(EntryFormScreen), findsOneWidget);
      expect(await entries.balanceOf(amazon), -5000, reason: 'a fatura continua como estava');
    });

    testWidgets('pagamento parcial (menos que o em aberto) é permitido e o resto fica no cartão', (
      tester,
    ) async {
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openNew(tester, '2000');
      await fillBill(tester, cardLabel(5000));
      await save(tester);

      expect(find.byType(EntryFormScreen), findsNothing);
      expect(await entries.balanceOf(amazon), -3000, reason: 'R\$ 30,00 seguem em aberto');
    });

    // --- Juros e encargos opcionais (feat 0014) ---

    final interestField = find.widgetWithText(TextField, 'Juros e encargos desta fatura (opcional)');

    Future<List<Entry>> cardEntries() async =>
        (await db.select(db.entries).get()).where((e) => e.accountId == amazon).toList();

    testWidgets('o campo de juros só existe em "Pagar fatura"', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openNew(tester, '1000');
      expect(interestField, findsNothing, reason: 'despesa comum');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Pagar fatura'));
      await tester.pumpAndSettle();
      expect(interestField, findsOneWidget);
    });

    testWidgets('juros informados liberam pagar acima do em aberto e viram um gasto no cartão', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openNew(tester, '5800');
      await fillBill(tester, cardLabel(5000));
      await tester.enterText(interestField, '800');
      await save(tester);

      expect(find.byType(EntryFormScreen), findsNothing);
      expect(await entries.balanceOf(amazon), 0, reason: '5000 + 800 de juros - 5800 pagos');
      expect(await entries.balanceOf(bradesco), 94200, reason: '100000 - 5800');
      final interest = (await cardEntries()).singleWhere((e) => e.description == 'Juros e encargos da fatura');
      expect(interest.amountCents, 800);
      expect(interest.type, EntryType.expense, reason: 'é gasto novo: entra nos totais do mês');
    });

    testWidgets('acima do em aberto MAIS o juros continua bloqueado e não grava nada', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openNew(tester, '6000');
      await fillBill(tester, cardLabel(5000));
      await tester.enterText(interestField, '500');
      await save(tester);

      expect(find.textContaining('Acima do que está em aberto'), findsOneWidget);
      expect(find.byType(EntryFormScreen), findsOneWidget);
      expect(await cardEntries(), hasLength(1), reason: 'só a compra: o juros não foi gravado sozinho');
      expect(await entries.balanceOf(amazon), -5000);
    });

    testWidgets('mostra ao vivo o que sobra: parcial, com juros e quitada', (tester) async {
      // A linha fica abaixo do campo de juros: numa janela baixa a lista nem a constrói.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openNew(tester, '2000');
      await fillBill(tester, cardLabel(5000));

      expect(
        find.textContaining('${Formatters.money(3000)} continuam em aberto e entram na próxima fatura'),
        findsOneWidget,
      );

      await tester.enterText(interestField, '1000'); // 5000 + 1000 - 2000
      await tester.pump();
      expect(find.textContaining('${Formatters.money(4000)} continuam em aberto'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '6000');
      await tester.pump();
      expect(find.textContaining('Fatura quitada'), findsOneWidget);
    });

    testWidgets('não diz "quitada" quando o valor passa do que pode ser pago (o erro aparece ao salvar)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openNew(tester, '6000'); // acima dos R$ 50,00 em aberto, sem juros
      await fillBill(tester, cardLabel(5000));

      expect(find.textContaining('Fatura quitada'), findsNothing);
      expect(find.textContaining('continuam em aberto'), findsNothing);
    });

    testWidgets('editar um pagamento existente não oferece o campo de juros', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      final paymentId = await entries.save(
        EntryDraft(
          accountId: bradesco,
          toAccountId: amazon,
          type: EntryType.billPayment,
          description: 'Pagamento fatura Amazon',
          amountCents: 2000,
          date: DateTime.now(),
        ),
      );
      await pumpApp(tester);
      GoRouter.of(tester.element(find.byType(MonthScreen))).push(EntryFormScreen.editPath(paymentId));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Valor'), findsOneWidget);
      expect(interestField, findsNothing, reason: 'o juros já é um gasto à parte, editável na lista');
    });

    testWidgets('cartão sem nada em aberto não recebe pagamento', (tester) async {
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await pumpApp(tester);
      await openNew(tester, '1000');
      await fillBill(tester, 'Amazon');
      await save(tester);

      expect(find.textContaining('Não há fatura em aberto'), findsOneWidget);
      expect(await entries.balanceOf(amazon), 0);
    });
  });

  test('o repositório continua sem validar saldo (a importação de planilha depende disso)', () async {
    // Bradesco sem nenhum saldo: o formulário bloquearia, o repositório não.
    await saveTransfer(5000);
    await entries.save(
      EntryDraft(
        accountId: bradesco,
        toAccountId: amazon,
        type: EntryType.billPayment,
        description: 'Pagamento fatura Amazon',
        amountCents: 99999, // cartão sem nada em aberto
        date: DateTime.now(),
      ),
    );

    expect(await entries.balanceOf(bradesco), -5000 - 99999);
  });
}
