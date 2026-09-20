import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/core/utils/year_month.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';

/// O aviso "Vai para: (mês)" do formulário tem de concordar com o mês que o
/// repositório grava. Sem isso a tela promete um mês e o lançamento cai em outro.
///
/// A data do formulário é hoje, então o cartão fecha **hoje**: é o caso do dia
/// do fechamento, o único em que as duas regras discordam.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
  });

  late AppDatabase db;
  late AccountsRepository accounts;
  late int owner;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    accounts = AccountsRepository(db, EntriesRepository(db));
    owner = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  /// Abre "Novo lançamento" para um cartão que fecha hoje e devolve o texto do aviso.
  Future<String> vaiPara(WidgetTester tester, {required bool inCurrent}) async {
    await accounts.create(
      name: 'Nubank',
      kind: AccountKind.creditCard,
      linkedAccountId: owner,
      closingDay: DateTime.now().day,
      closingDayInCurrent: inCurrent,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Novo lançamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Nubank · cartão do Bradesco'));
    await tester.pumpAndSettle();
    return tester.widget<Text>(find.textContaining('Vai para:')).data!;
  }

  final now = DateTime.now();
  final thisMonth = YearMonth.of(now);

  testWidgets('cartão em "fatura atual": no dia do fechamento o aviso mostra o mês corrente', (tester) async {
    expect(await vaiPara(tester, inCurrent: true), 'Vai para: ${thisMonth.label}');
  });

  testWidgets('cartão em "próxima fatura": no dia do fechamento o aviso mostra o mês seguinte', (tester) async {
    expect(await vaiPara(tester, inCurrent: false), 'Vai para: ${thisMonth.next().label}');
  });
}
