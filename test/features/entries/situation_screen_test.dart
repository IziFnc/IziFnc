import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ambrio/core/widgets/money_text.dart';
import 'package:ambrio/core/database/app_database.dart';
import 'package:ambrio/core/database/database_provider.dart';
import 'package:ambrio/core/utils/clock.dart';
import 'package:ambrio/core/utils/formatters.dart';
import 'package:ambrio/core/utils/year_month.dart';
import 'package:ambrio/features/accounts/data/accounts_repository.dart';
import 'package:ambrio/features/accounts/domain/account_kind.dart';
import 'package:ambrio/features/entries/data/entries_repository.dart';
import 'package:ambrio/features/entries/domain/entry_type.dart';
import 'package:ambrio/features/entries/presentation/situation_screen.dart';

import '../../support/real_fonts.dart';

/// A tela de situação (feat 0042): cada conta, cada cartão com o vencimento mais
/// perto primeiro, e os saldos ao vivo.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;
  late EntriesRepository entries;
  late int bradesco;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    entries = EntriesRepository(db, now: () => DateTime(2026, 11, 10));
    final accounts = AccountsRepository(db, entries);
    bradesco = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    // Vence dia 20 (daqui a 10 dias) e dia 12 (daqui a 2): o dia 12 vem primeiro.
    final longe = await accounts.create(
      name: 'Longe',
      kind: AccountKind.creditCard,
      linkedAccountId: bradesco,
      closingDay: 31,
      dueDay: 20,
    );
    final perto = await accounts.create(
      name: 'Perto',
      kind: AccountKind.creditCard,
      linkedAccountId: bradesco,
      closingDay: 31,
      dueDay: 12,
    );
    Future<void> spend(int account, int cents) => entries.save(
      EntryDraft(
        accountId: account,
        type: EntryType.expense,
        description: 'compra',
        amountCents: cents,
        date: DateTime(2026, 11, 3),
      ),
    );
    await spend(longe, 10000);
    await spend(perto, 20000);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          balancesHiddenAtStartProvider.overrideWithValue(false), // estes testes olham os valores
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 10)),
        ],
        child: const MaterialApp(home: SituationScreen(month: YearMonth(2026, 11))),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista as contas e os cartões, com o vencimento mais perto primeiro', (tester) async {
    await pump(tester);

    expect(find.text('Seu dinheiro'), findsOneWidget);
    expect(find.text('Bradesco'), findsOneWidget);
    expect(find.text('O que você deve'), findsOneWidget);

    final perto = tester.getTopLeft(find.text('Cartão Perto')).dy;
    final longe = tester.getTopLeft(find.text('Cartão Longe')).dy;
    expect(perto, lessThan(longe), reason: 'vence dia 12, antes do dia 20');
    expect(find.textContaining('vence em 2 dias'), findsOneWidget);
    expect(find.textContaining('vence em 10 dias'), findsOneWidget);
  });

  testWidgets('os saldos atualizam ao vivo (a folha antiga mostrava um retrato)', (tester) async {
    await pump(tester);
    expect(find.textContaining(Formatters.money(30000)), findsWidgets, reason: 'faturas abertas: 100 + 200');

    await tester.runAsync(
      () => entries.save(
        EntryDraft(
          accountId: bradesco,
          type: EntryType.income,
          description: 'salário',
          amountCents: 500000,
          date: DateTime(2026, 11, 4),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(Formatters.money(500000)), findsWidgets, reason: 'Em conta subiu sem reabrir a tela');
  });
}
