import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/core/utils/clock.dart';
import 'package:izifnc/core/utils/year_month.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';

/// O aviso "Vai para: (mês)" do formulário tem de concordar com o mês que o
/// repositório grava. Sem isso a tela promete um mês e o lançamento cai em outro.
///
/// A data do formulário é "hoje" do relógio fixo abaixo (dia 22), então o
/// cartão fecha **hoje**: é o caso do dia do fechamento, o único em que as duas
/// regras discordam. O relógio é fixo para o teste não depender do dia em que roda.
void main() {
  final fixedNow = DateTime(2026, 9, 22, 12);

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
    accounts = AccountsRepository(db, EntriesRepository(db, now: () => fixedNow));
    owner = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  /// Abre "Novo lançamento" para um cartão que fecha hoje e devolve o texto do aviso.
  Future<String> vaiPara(WidgetTester tester, {required bool inCurrent, int? closingDay}) async {
    await accounts.create(
      name: 'Nubank',
      kind: AccountKind.creditCard,
      linkedAccountId: owner,
      closingDay: closingDay ?? fixedNow.day,
      closingDayInCurrent: inCurrent,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tourEnabledProvider.overrideWithValue(false),
          clockProvider.overrideWithValue(() => fixedNow),
        ],
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

  final thisMonth = YearMonth.of(fixedNow);

  testWidgets('cartão em "fatura atual": no dia do fechamento o aviso mostra o mês corrente', (tester) async {
    expect(await vaiPara(tester, inCurrent: true), 'Vai para: ${thisMonth.label}');
  });

  testWidgets('cartão em "próxima fatura": no dia do fechamento o aviso mostra o mês seguinte', (tester) async {
    expect(await vaiPara(tester, inCurrent: false), 'Vai para: ${thisMonth.next().label}');
  });
  // Depois do fechamento (dia 10, hoje é 22) a compra cai na próxima fatura
  // nas duas regras: o dia do fechamento só importa quando é hoje.
  testWidgets('compra depois do dia do fechamento vai para o mês seguinte, qualquer que seja a regra', (tester) async {
    expect(await vaiPara(tester, inCurrent: true, closingDay: 10), 'Vai para: ${thisMonth.next().label}');
  });
}
