import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ambrio/core/widgets/money_text.dart';
import 'package:ambrio/app.dart';
import 'package:ambrio/core/database/app_database.dart';
import 'package:ambrio/core/database/database_provider.dart';
import 'package:ambrio/core/utils/formatters.dart';
import 'package:ambrio/core/widgets/tour_target.dart';
import 'package:ambrio/features/accounts/data/accounts_repository.dart';
import 'package:ambrio/features/accounts/domain/account_kind.dart';
import 'package:ambrio/features/accounts/presentation/account_form_screen.dart';
import 'package:ambrio/features/accounts/presentation/accounts_screen.dart';
import 'package:ambrio/features/entries/data/entries_repository.dart';
import 'package:ambrio/features/entries/domain/entry_type.dart';
import 'package:ambrio/features/entries/presentation/entry_form_screen.dart';
import 'package:ambrio/features/entries/presentation/month_screen.dart';

/// Os acertos de UX da 1.0.3 (feat 0042), vindos dos júris da 1.0.2.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
  });

  late AppDatabase db;
  late EntriesRepository entries;
  late AccountsRepository accounts;
  late int bradesco;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    entries = EntriesRepository(db);
    accounts = AccountsRepository(db, entries);
    bradesco = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [balancesHiddenAtStartProvider.overrideWithValue(false), appDatabaseProvider.overrideWithValue(db), tourEnabledProvider.overrideWithValue(false)],
        child: const AmbrioApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String path) async {
    GoRouter.of(tester.element(find.byType(MonthScreen))).push(path);
    await tester.pumpAndSettle();
  }

  testWidgets('a lista de contas mostra o saldo de hoje e o em aberto do cartão (Q5)', (tester) async {
    await entries.adjustBalance(accountId: bradesco, target: 123456);
    final amazon = await accounts.create(
      name: 'Amazon',
      kind: AccountKind.creditCard,
      closingDay: 31,
      linkedAccountId: bradesco,
    );
    await entries.save(
      EntryDraft(
        accountId: amazon,
        type: EntryType.expense,
        description: 'Mouse',
        amountCents: 5000,
        date: DateTime.now(),
      ),
    );
    await pumpApp(tester);
    await go(tester, AccountsScreen.path);

    expect(find.text(Formatters.money(123456)), findsOneWidget, reason: 'saldo da conta');
    expect(find.text('${Formatters.money(5000)} em aberto'), findsOneWidget, reason: 'fatura do cartão');
  });

  testWidgets('o campo do saldo explica que os dígitos entram como centavos (Q1)', (tester) async {
    await pumpApp(tester);
    await go(tester, AccountFormScreen.editPath(bradesco));
    await tester.tap(find.text('Ajustar saldo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('150000 vira'), findsOneWidget);
  });

  testWidgets('o nome da conta não força maiúscula em cada palavra (Q8)', (tester) async {
    await pumpApp(tester);
    await go(tester, AccountFormScreen.newPath);

    final name = tester.widget<TextField>(find.widgetWithText(TextField, 'Nome'));
    expect(name.textCapitalization, TextCapitalization.sentences, reason: '"Conta do banco", não "Conta Do Banco"');
  });

  testWidgets('com uma conta só, a transferência diz por que está desligada (Q9)', (tester) async {
    await pumpApp(tester);
    await go(tester, EntryFormScreen.newPath);

    expect(find.text('Transferência precisa de duas contas.'), findsOneWidget);
  });

  testWidgets('com duas contas, a explicação da transferência some', (tester) async {
    await accounts.create(name: 'C6', kind: AccountKind.checking);
    await pumpApp(tester);
    await go(tester, EntryFormScreen.newPath);

    expect(find.text('Transferência precisa de duas contas.'), findsNothing);
  });

  testWidgets('"Escolha de onde sai" aparece neutro antes de salvar, sem pintar de erro (R6)', (tester) async {
    await accounts.create(name: 'C6', kind: AccountKind.checking);
    await pumpApp(tester);
    await go(tester, EntryFormScreen.newPath);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transferência'));
    await tester.pumpAndSettle();

    final hint = find.text('Escolha de onde sai');
    expect(hint, findsOneWidget);
    final style = tester.widget<Text>(hint).style;
    expect(style?.color, isNot(Theme.of(tester.element(hint)).colorScheme.error), reason: 'ainda não é erro');
  });
}
