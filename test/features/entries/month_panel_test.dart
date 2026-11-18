import 'package:ambrio/core/database/app_database.dart';
import 'package:ambrio/core/utils/clock.dart';
import 'package:ambrio/core/widgets/money_text.dart';
import 'package:ambrio/features/accounts/domain/account_kind.dart';
import 'package:ambrio/features/entries/domain/month_panel.dart';
import 'package:ambrio/features/entries/domain/month_situation.dart';
import 'package:ambrio/features/entries/domain/month_summary.dart';
import 'package:ambrio/features/entries/presentation/month_panel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _at = DateTime(2025);
final _today = DateTime(2026, 11, 17);

Account _account(
  int id,
  String name, {
  AccountKind kind = AccountKind.checking,
  int? dueDay,
}) => Account(
  id: id,
  name: name,
  kind: kind,
  dueDay: dueDay,
  closingDayInCurrent: false,
  createdAt: _at,
);

MonthSituation _situation({
  int income = 500000,
  int spentDebit = 150000,
  int spentCards = 260000,
  Map<int, int>? balances,
  List<Account>? accounts,
}) {
  final nubank = _account(
    3,
    'Nubank',
    kind: AccountKind.creditCard,
    dueDay: 20,
  );
  final inter = _account(4, 'Inter', kind: AccountKind.creditCard, dueDay: 29);
  return MonthSituation.from(
    accounts:
        accounts ?? [_account(1, 'Azul'), _account(2, 'Verde'), nubank, inter],
    balances: balances ?? {1: 300000, 2: 123010, 3: -120000, 4: -70000},
    summary: MonthSummary(
      incomeCents: income,
      debitExpenseCents: spentDebit,
      cards: [(card: nubank, cents: spentCards)],
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('MonthPanel (domínio)', () {
    test('o gasto em percentual do que entrou, arredondado, e a barra a partir do zero', () {
      final p = MonthPanel.from(
        situation: _situation(),
        today: _today,
      ); // 410.000 de 500.000
      expect(p.spentPercent, 82);
      expect(p.spentFraction, closeTo(0.82, 1e-9));
      expect(p.overflow, isFalse);
      expect(p.phrase, 'Gastou 82% do que entrou');
    });

    test('gastou mais do que entrou: a barra enche, passa de 100% e a frase diz "acima"', () {
      final p = MonthPanel.from(
        situation: _situation(income: 100000),
        today: _today,
      ); // 410.000 de 100.000
      expect(p.overflow, isTrue);
      expect(p.spentPercent, 410);
      expect(p.spentFraction, 1.0, reason: 'a barra não passa do fim');
      expect(p.phrase, 'Gastou 410% do que entrou');
    });

    test('sem entradas não há percentual: a frase diz isso em vez de dividir por zero', () {
      final p = MonthPanel.from(
        situation: _situation(income: 0),
        today: _today,
      );
      expect(p.hasIncome, isFalse);
      expect(p.spentPercent, isNull);
      expect(p.spentFraction, 0);
      expect(p.phrase, 'Sem entradas neste mês');
    });

    test('mês sem nenhum movimento', () {
      final p = MonthPanel.from(
        situation: _situation(income: 0, spentDebit: 0, spentCards: 0),
        today: _today,
      );
      expect(p.phrase, 'Sem movimento neste mês');
    });

    test('o vencimento mais próximo entre os cartões com algo em aberto', () {
      final p = MonthPanel.from(
        situation: _situation(),
        today: _today,
      ); // Nubank dia 20 (3 dias), Inter dia 29
      expect(p.nextDue!.card.name, 'Nubank');
      expect(p.nextDue!.due.daysUntil, 3);
      expect(p.nextDue!.due.label, 'vence em 3 dias');
    });

    test('cartão sem fatura em aberto ou sem dia de vencimento não entra', () {
      final semFatura = MonthPanel.from(
        situation: _situation(balances: {1: 1, 2: 1, 3: 0, 4: -70000}),
        today: _today,
      );
      expect(
        semFatura.nextDue!.card.name,
        'Inter',
        reason: 'o Nubank está quitado',
      );

      final semDia = MonthPanel.from(
        situation: _situation(
          accounts: [
            _account(1, 'Azul'),
            _account(3, 'Nubank', kind: AccountKind.creditCard),
          ],
          balances: {1: 1, 3: -5000},
        ),
        today: _today,
      );
      expect(semDia.nextDue, isNull);
    });
  });

  group('MonthPanelCard (tela)', () {
    Widget host({
      bool hiddenAtStart = true,
      double textScale = 1.0,
      int income = 500000,
      VoidCallback? onTap,
    }) {
      return ProviderScope(
        overrides: [
          balancesHiddenAtStartProvider.overrideWithValue(hiddenAtStart),
          clockProvider.overrideWithValue(() => _today),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(textScale),
              size: const Size(360, 800),
            ),
            child: Scaffold(
              body: ListView(
                children: [
                  MonthPanelCard(
                    situation: _situation(income: income),
                    monthLoaded: true,
                    onTap: onTap ?? () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'escondido: sem reais, mas com barras, percentual e vencimento',
      (tester) async {
        await tester.pumpWidget(host());

        expect(
          find.text(kHiddenMoney),
          findsOneWidget,
          reason: 'o saldo em conta, escondido',
        );
        expect(find.text('Gastou 82% do que entrou'), findsOneWidget);
        expect(
          find.text('Entrou'),
          findsNothing,
          reason: 'uma barra "Entrou" sempre cheia não diz nada',
        );
        expect(find.text('100%'), findsNothing);
        expect(find.text('Cartão Nubank vence em 3 dias'), findsOneWidget);
        expect(
          find.textContaining('R\$ 4'),
          findsNothing,
          reason: 'nenhum valor em reais aparece',
        );
      },
    );

    testWidgets('com o olhinho aberto também mostra quanto entrou e gastou', (
      tester,
    ) async {
      await tester.pumpWidget(host(hiddenAtStart: false));

      expect(find.textContaining('Entrou R\$'), findsOneWidget);
      expect(find.textContaining('Gastou R\$'), findsOneWidget);
    });

    testWidgets('o olhinho do painel alterna', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byTooltip('Mostrar valores'));
      await tester.pump();
      expect(find.byTooltip('Ocultar valores'), findsOneWidget);
      expect(find.text(kHiddenMoney), findsNothing);
    });

    testWidgets('gastou acima do que entrou: ícone e palavra, não só cor', (
      tester,
    ) async {
      await tester.pumpWidget(host(income: 100000));

      expect(find.text('Gastou acima do que entrou'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Gastou 410% do que entrou'), findsOneWidget);
    });

    testWidgets('tocar abre a situação', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(onTap: () => taps++));

      await tester.tap(find.text('Gastou 82% do que entrou'));
      expect(taps, 1);
    });

    testWidgets(
      'leitor de tela: fala o painel sem ler os reais quando escondidos',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(host());

        expect(
          find.bySemanticsLabel(
            'Em conta, valor oculto. Gastou 82% do que entrou. Cartão Nubank vence em 3 dias. Toque para ver a situação',
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('texto grande (200%): rótulo acima da barra, sem cortar', (
      tester,
    ) async {
      await tester.pumpWidget(host(textScale: 2.0));

      expect(find.text('Gastou 82% do que entrou'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'sem estouro de layout');
    });
  });
}
