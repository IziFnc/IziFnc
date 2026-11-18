import 'package:ambrio/core/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// O olhinho dos saldos (feat 0048): o app abre com os valores escondidos, o botão
/// alterna, e o leitor de tela ouve "valor oculto" em vez de pontinhos.
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Widget host({List<Override> overrides = const []}) => ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            BalancesEyeButton(),
            MoneyText(123456, prefix: 'Em conta '),
            MoneyText(5000, suffix: ' em aberto'),
          ],
        ),
      ),
    ),
  );

  testWidgets('começa escondido: nenhum número aparece', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Em conta $kHiddenMoney'), findsOneWidget);
    expect(find.text('$kHiddenMoney em aberto'), findsOneWidget);
    expect(find.textContaining('1.234'), findsNothing);
    expect(find.byTooltip('Mostrar valores'), findsOneWidget);
  });

  testWidgets('o olhinho mostra e esconde de novo', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byTooltip('Mostrar valores'));
    await tester.pump();
    expect(find.textContaining('1.234,56'), findsOneWidget);
    expect(find.byTooltip('Ocultar valores'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar valores'));
    await tester.pump();
    expect(find.textContaining('1.234'), findsNothing);
  });

  testWidgets('escondido, o leitor de tela ouve "valor oculto"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());

    expect(find.bySemanticsLabel('Em conta valor oculto'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('R\\\$ •')), findsNothing);
    handle.dispose();
  });

  testWidgets('o padrão visível vale para quem sobrescreve (testes de tela)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(overrides: [balancesHiddenAtStartProvider.overrideWithValue(false)]),
    );

    expect(find.textContaining('1.234,56'), findsOneWidget);
  });
}
