import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

/// Passar os meses arrastando para o lado, além das setas (feat 0053).
///
/// Arrastar para a **esquerda** vai para o mês seguinte e para a **direita** para o anterior,
/// como virar páginas. Para não brigar com o resto:
///
/// * a rolagem vertical da lista continua intacta (só conta arrasto horizontal);
/// * um arrasto que **começa na borda** da tela é ignorado: o Android usa a borda esquerda para
///   abrir o menu e as duas bordas para o gesto de voltar;
/// * o gesto precisa ser deliberado: pelo menos [minDistance] com alguma velocidade, ou um arrasto
///   bem longo (para quem arrasta devagar). Um toque ou um deslize curto não troca o mês.
///
/// As setas continuam, e o leitor de tela ganha as ações "Mês anterior" e "Próximo mês".
class MonthSwipe extends StatefulWidget {
  const MonthSwipe({
    super.key,
    required this.monthKey,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  /// Identifica o mês mostrado (a troca ganha um esmaecer curto).
  final Object monthKey;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  /// Largura da faixa da borda onde o arrasto é ignorado.
  static const double edge = 28;

  /// Distância mínima (com velocidade) e distância que vale sozinha.
  static const double minDistance = 72;
  static const double longDistance = 160;
  static const double minVelocity = 250;

  @override
  State<MonthSwipe> createState() => _MonthSwipeState();
}

class _MonthSwipeState extends State<MonthSwipe> {
  double _dx = 0;
  bool _ignore = false;

  void _start(DragStartDetails d) {
    final width = MediaQuery.sizeOf(context).width;
    _ignore =
        d.globalPosition.dx < MonthSwipe.edge ||
        d.globalPosition.dx > width - MonthSwipe.edge;
    _dx = 0;
  }

  void _end(DragEndDetails d) {
    if (_ignore) return;
    final velocity = d.primaryVelocity ?? 0;
    final distance = _dx.abs();
    final deliberate =
        (distance >= MonthSwipe.minDistance &&
            velocity.abs() >= MonthSwipe.minVelocity &&
            velocity.sign == _dx.sign) ||
        distance >= MonthSwipe.longDistance;
    if (!deliberate) return;
    if (_dx < 0) {
      widget.onNext();
    } else {
      widget.onPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Mês anterior'): widget.onPrevious,
        const CustomSemanticsAction(label: 'Próximo mês'): widget.onNext,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // A posição do começo é a do toque inicial (para saber se foi na borda), não a de depois do atrito.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _start,
        onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
        onHorizontalDragEnd: _end,
        child: AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          child: KeyedSubtree(
            key: ValueKey(widget.monthKey),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
