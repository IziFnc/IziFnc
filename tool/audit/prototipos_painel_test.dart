// Protótipos do painel da tela inicial (Ateliê, 2026-11-17): três propostas desenhadas
// com widgets e dados FICTÍCIOS, como imagens para o "teste dos cinco segundos". Fora de
// `test/`, não roda no CI.
//
//     AUDIT_OUT=<pasta> flutter test tool/audit/prototipos_painel_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ambrio/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../test/support/real_fonts.dart';

final out = Platform.environment['AUDIT_OUT'] ?? '${Directory.systemTemp.path}${Platform.pathSeparator}painel';
const hidden = 'R\$ ••••';

/// Gabarito: Em conta R$ 4.230,10 (escondido). Nubank vence em 3 dias, Inter em 12.
/// Entrou 5.000, gastou 4.100 (82%; débito 40%, cartões 60%).
Widget _shell(Widget panel, {required bool dark}) {
  final theme = dark ? AppTheme.dark() : AppTheme.light();
  Widget row(IconData icon, String title, String sub, String value) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(sub),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.menu),
        title: const Text('Novembro de 2026'),
        actions: const [Icon(Icons.search), SizedBox(width: 12), Icon(Icons.tune), SizedBox(width: 12)],
      ),
      body: ListView(
        children: [
          panel,
          row(Icons.account_balance_outlined, 'Freela', '19/11 · Verde', '+ R\$ 850,00'),
          row(Icons.account_balance_outlined, 'Internet', '18/11 · Azul', 'R\$ 99,90'),
          row(Icons.credit_card, 'Jantar', '13/11 · Nubank · cartão', 'R\$ 187,00'),
          row(Icons.credit_card, 'Livro de design', '12/11 · Inter · cartão', 'R\$ 89,90'),
          row(Icons.account_balance_outlined, 'Mercado', '08/11 · Azul', 'R\$ 234,50'),
        ],
      ),
    ),
  );
}

Widget _eye(BuildContext context) => const Icon(Icons.visibility_outlined);

/// A: um número e uma frase.
class PanelA extends StatelessWidget {
  const PanelA({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Em conta', style: t.textTheme.labelLarge)),
                _eye(context),
              ],
            ),
            Text(hidden, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 6),
                Text('Cartão Nubank vence em 3 dias', style: t.textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: 6),
            Text('Entrou $hidden · Gastou $hidden', style: t.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// B: barras do mês e o que vence.
class PanelB extends StatelessWidget {
  const PanelB({super.key});

  Widget bar(BuildContext context, String label, double fraction, String pct, {Widget? inner}) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: t.textTheme.bodyMedium)),
          Expanded(
            child: Stack(
              children: [
                Container(height: 16, decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: inner ?? Container(height: 16, decoration: BoxDecoration(color: t.colorScheme.primary, borderRadius: BorderRadius.circular(4))),
                ),
              ],
            ),
          ),
          SizedBox(width: 48, child: Text(pct, textAlign: TextAlign.end, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    Widget due(String name, String when) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: t.textTheme.bodyLarge)),
          Text(when, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Neste mês', style: t.textTheme.titleSmall)),
                _eye(context),
              ],
            ),
            const SizedBox(height: 8),
            bar(context, 'Entrou', 1, '100%'),
            bar(
              context,
              'Gastou',
              0.82,
              '82%',
              inner: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    Expanded(flex: 40, child: Container(decoration: BoxDecoration(color: scheme.primary, borderRadius: const BorderRadius.horizontal(left: Radius.circular(4))))),
                    Expanded(flex: 60, child: Container(decoration: BoxDecoration(color: scheme.tertiary, border: Border.all(color: scheme.primary), borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))))),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Row(
                children: [
                  Container(width: 10, height: 10, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text('débito 40%', style: t.textTheme.bodySmall),
                  const SizedBox(width: 12),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: scheme.tertiary, border: Border.all(color: scheme.primary))),
                  const SizedBox(width: 4),
                  Text('cartões 60%', style: t.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('Em conta $hidden  ·  Faturas $hidden', style: t.textTheme.bodyMedium),
            const Divider(height: 20),
            Text('Vence em breve', style: t.textTheme.labelLarge),
            due('Cartão Nubank', 'vence em 3 dias'),
            due('Cartão Inter', 'vence em 12 dias'),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.fg, this.bg);
  final double fraction;
  final Color fg;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(4), 0, math.pi * 2, false, p..color = bg);
    canvas.drawArc(rect.deflate(4), -math.pi / 2, math.pi * 2 * fraction, false, p..color = fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction;
}

/// C: faixa de cartões com anel.
class PanelC extends StatelessWidget {
  const PanelC({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    Widget cardTile(String name, double frac, String days) => Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _RingPainter(frac, scheme.primary, scheme.surfaceContainerHigh),
              child: Center(child: Text(days, style: t.textTheme.labelLarge)),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: t.textTheme.bodyMedium),
          Text(hidden, style: t.textTheme.bodySmall),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Em conta $hidden', style: t.textTheme.titleMedium)),
                _eye(context),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [cardTile('Nubank', 0.63, '3d'), cardTile('Inter', 0.37, '12d')]),
            ),
            const SizedBox(height: 10),
            Text('Entrou $hidden · Gastou $hidden', style: t.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
    Directory(out).createSync(recursive: true);
  });

  final proposals = <String, Widget>{'A': const PanelA(), 'B': const PanelB(), 'C': const PanelC()};
  for (final dark in [false, true]) {
    for (final e in proposals.entries) {
      testWidgets('proposta ${e.key} ${dark ? 'escuro' : 'claro'}', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: _shell(e.value, dark: dark)));
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/proposta-${e.key}-${dark ? 'escuro' : 'claro'}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
