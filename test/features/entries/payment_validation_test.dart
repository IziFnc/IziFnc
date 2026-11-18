import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ambrio/app.dart';
import 'package:ambrio/core/database/app_database.dart';
import 'package:ambrio/core/database/database_provider.dart';
import 'package:ambrio/core/utils/formatters.dart';
import 'package:ambrio/core/widgets/tour_target.dart';
import 'package:ambrio/features/accounts/data/accounts_repository.dart';
import 'package:ambrio/features/accounts/domain/account_kind.dart';
import 'package:ambrio/features/entries/data/entries_repository.dart';
import 'package:ambrio/features/entries/domain/entry_type.dart';
import 'package:ambrio/features/entries/presentation/bill_payment_screen.dart';
import 'package:ambrio/features/entries/presentation/entry_form_screen.dart';
import 'package:ambrio/features/entries/presentation/month_screen.dart';

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
        child: const AmbrioApp(),
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

  group('pagar fatura (tela própria, feat 0042)', () {
    /// Abre a tela de pagamento do Amazon, como o botão "Pagar fatura" faz.
    Future<void> openBill(WidgetTester tester) async {
      GoRouter.of(tester.element(find.byType(MonthScreen))).push(BillPaymentScreen.pathFor(amazon));
      await tester.pumpAndSettle();
    }

    final valueField = find.widgetWithText(TextField, 'Valor');
    final interestField = find.widgetWithText(TextField, 'Juros e encargos desta fatura (opcional)');
    final payButton = find.byType(FilledButton);

    Future<void> pay(WidgetTester tester) async {
      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();
    }

    Future<List<Entry>> cardEntries() async =>
        (await db.select(db.entries).get()).where((e) => e.accountId == amazon).toList();

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('já vem com o valor em aberto, a conta dona escolhida e o juros opcional', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);

      expect(tester.widget<TextField>(valueField).controller!.text, Formatters.money(5000));
      final saiDe = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Bradesco'));
      expect(saiDe.selected, isTrue, reason: 'conta dona pré-selecionada');
      expect(interestField, findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Pagar fatura'), findsNothing, reason: 'o formulário não oferece mais');
    });

    testWidgets('acima do que está em aberto é bloqueado', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.enterText(valueField, '6000');
      await pay(tester);

      expect(find.textContaining('Acima do que está em aberto'), findsNWidgets(2), reason: 'no campo e junto do botão');
      expect(find.byType(BillPaymentScreen), findsOneWidget);
      expect(await entries.balanceOf(amazon), -5000, reason: 'a fatura continua como estava');
    });

    testWidgets('pagamento parcial (menos que o em aberto) é permitido e o resto fica no cartão', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.enterText(valueField, '2000');
      await pay(tester);

      expect(find.byType(BillPaymentScreen), findsNothing);
      expect(await entries.balanceOf(amazon), -3000, reason: 'R\$ 30,00 seguem em aberto');
    });

    testWidgets('juros informados liberam pagar acima do em aberto e viram um gasto no cartão', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.enterText(valueField, '5800');
      await tester.enterText(interestField, '800');
      await pay(tester);

      expect(find.byType(BillPaymentScreen), findsNothing);
      expect(await entries.balanceOf(amazon), 0, reason: '5000 + 800 de juros - 5800 pagos');
      expect(await entries.balanceOf(bradesco), 94200, reason: '100000 - 5800');
      final interest = (await cardEntries()).singleWhere((e) => e.description == 'Juros e encargos da fatura');
      expect(interest.amountCents, 800);
      expect(interest.type, EntryType.expense, reason: 'é gasto novo: entra nos totais do mês');
    });

    testWidgets('acima do em aberto MAIS o juros continua bloqueado e não grava nada', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.enterText(valueField, '6000');
      await tester.enterText(interestField, '500');
      await pay(tester);

      expect(find.textContaining('Acima do que está em aberto'), findsNWidgets(2), reason: 'no campo e junto do botão');
      expect(find.byType(BillPaymentScreen), findsOneWidget);
      expect(await cardEntries(), hasLength(1), reason: 'só a compra: o juros não foi gravado sozinho');
      expect(await entries.balanceOf(amazon), -5000);
    });

    testWidgets('mostra ao vivo o que sobra: parcial, com juros e quitada', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.enterText(valueField, '2000');
      await tester.pump();

      expect(
        find.textContaining('${Formatters.money(3000)} continuam em aberto e entram na próxima fatura'),
        findsOneWidget,
      );

      await tester.enterText(interestField, '1000'); // 5000 + 1000 - 2000
      await tester.pump();
      expect(find.textContaining('${Formatters.money(4000)} continuam em aberto'), findsOneWidget);

      await tester.enterText(valueField, '6000');
      await tester.pump();
      expect(find.textContaining('a fatura fica quitada'), findsOneWidget);
    });

    testWidgets('não diz "quitada" quando o valor passa do que pode ser pago (o erro aparece ao pagar)', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.enterText(valueField, '6000'); // acima dos R$ 50,00 em aberto, sem juros
      await tester.pump();

      expect(find.textContaining('fica quitada'), findsNothing);
      expect(find.textContaining('continuam em aberto'), findsNothing);
    });

    testWidgets('editar um pagamento existente continua no formulário, sem campo de juros', (tester) async {
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

      expect(valueField, findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Pagar fatura'), findsOneWidget, reason: 'o tipo ainda aparece ao editar');
      expect(interestField, findsNothing, reason: 'o juros já é um gasto à parte, editável na lista');
    });

    testWidgets('cartão sem nada em aberto não recebe pagamento sem juros', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await pumpApp(tester);
      await openBill(tester);

      expect(find.textContaining('Não há fatura em aberto neste cartão'), findsOneWidget);
      expect(tester.widget<FilledButton>(payButton).onPressed, isNull, reason: 'sem valor nem juros, nada a pagar');
      expect(await entries.balanceOf(amazon), 0);
    });

    testWidgets('cartão sem fatura aceita pagar só os juros e encargos que o banco cobrou', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.enterText(valueField, '800');
      await tester.enterText(interestField, '800');
      await tester.pump(); // o botão só liga depois de o juros entrar na conta
      await pay(tester);

      expect(find.byType(BillPaymentScreen), findsNothing);
      expect(await entries.balanceOf(amazon), 0, reason: '800 de juros - 800 pagos');
      expect(await entries.balanceOf(bradesco), 99200);
    });

    testWidgets('grava a descrição "Pagamento fatura Amazon" e a conta de origem', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await pay(tester);

      final payment = (await db.select(db.entries).get()).singleWhere((e) => e.type == EntryType.billPayment);
      expect(payment.description, 'Pagamento fatura Amazon');
      expect(payment.accountId, bradesco);
      expect(payment.toAccountId, amazon);
      expect(payment.amountCents, 5000, reason: 'o valor já vinha preenchido com o em aberto');
    });

    testWidgets('dois toques seguidos em Pagar gravam um pagamento só', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.tap(payButton, warnIfMissed: false); // segundo toque antes de gravar
      await tester.pumpAndSettle();

      final payments = (await db.select(db.entries).get()).where((e) => e.type == EntryType.billPayment);
      expect(payments, hasLength(1));
      expect(await entries.balanceOf(amazon), 0);
    });

    testWidgets('mostra o erro também perto do botão (com texto grande o campo fica longe)', (tester) async {
      tall(tester);
      await entries.adjustBalance(accountId: bradesco, target: 100000);
      await buy(5000);
      await pumpApp(tester);
      await openBill(tester);
      await tester.enterText(valueField, '6000');
      await pay(tester);

      expect(find.textContaining('Acima do que está em aberto'), findsNWidgets(2), reason: 'no campo e junto do botão');
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
