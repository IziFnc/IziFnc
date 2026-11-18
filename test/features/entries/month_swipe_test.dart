import 'package:ambrio/features/entries/presentation/month_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Passar os meses por gesto (feat 0053): só um arrasto horizontal deliberado troca o mês;
/// rolar a lista, tocar, arrastar da borda ou um deslize curto não.
void main() {
  late int next;
  late int previous;

  setUp(() {
    next = 0;
    previous = 0;
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3; // 360 dp de largura
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthSwipe(
            monthKey: 'nov',
            onNext: () => next++,
            onPrevious: () => previous++,
            child: ListView(
              children: [for (var i = 0; i < 30; i++) ListTile(title: Text('Linha $i'))],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('arrastar para a esquerda vai para o mês seguinte', (tester) async {
    await pump(tester);
    await tester.fling(find.text('Linha 3'), const Offset(-160, 0), 800);
    await tester.pumpAndSettle();
    expect(next, 1);
    expect(previous, 0);
  });

  testWidgets('arrastar para a direita volta o mês', (tester) async {
    await pump(tester);
    await tester.fling(find.text('Linha 3'), const Offset(160, 0), 800);
    await tester.pumpAndSettle();
    expect(previous, 1);
    expect(next, 0);
  });

  testWidgets('um deslize curto não troca o mês', (tester) async {
    await pump(tester);
    await tester.fling(find.text('Linha 3'), const Offset(-40, 0), 800);
    await tester.pumpAndSettle();
    expect(next + previous, 0);
  });

  testWidgets('rolar a lista na vertical não troca o mês', (tester) async {
    await pump(tester);
    await tester.fling(find.text('Linha 3'), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    expect(next + previous, 0);
    expect(find.text('Linha 0'), findsNothing, reason: 'a lista rolou normalmente');
  });

  testWidgets('um arrasto que começa na borda é ignorado (menu e voltar do Android)', (tester) async {
    await pump(tester);
    await tester.flingFrom(const Offset(8, 300), const Offset(200, 0), 900);
    await tester.pumpAndSettle();
    expect(next + previous, 0, reason: 'a borda esquerda é do menu');

    await tester.flingFrom(const Offset(352, 300), const Offset(-200, 0), 900);
    await tester.pumpAndSettle();
    expect(next + previous, 0, reason: 'a borda direita é do gesto de voltar');
  });

  testWidgets('um arrasto bem longo e lento também vale (quem arrasta devagar)', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-16, 0));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 400)); // parado antes de soltar: velocidade ~0
    await gesture.up();
    await tester.pumpAndSettle();
    expect(next, 1);
  });

  testWidgets('o leitor de tela ganha as ações "Mês anterior" e "Próximo mês"', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final node = tester.getSemantics(find.byType(MonthSwipe));
    final actions = node.getSemanticsData().customSemanticsActionIds ?? const [];
    expect(actions, hasLength(2));
    handle.dispose();
  });
}
