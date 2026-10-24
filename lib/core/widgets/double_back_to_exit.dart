import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Embrulha um destino do menu lateral (`AppDrawer`, feature 0010): esses
/// destinos **trocam** de tela (`context.go`, sem empilhar), então voltar a
/// partir de qualquer um deles fecharia o app com um só gesto — surpreendia
/// gente testando (achado ao vivo, feat 0026: o tour leva a Importar planilha
/// e Configurações assim). Agora exige dois gestos seguidos: o primeiro
/// mostra um aviso, o segundo (dentro de 2s) fecha de verdade.
///
/// Não faz nada quando a tela **tem** para onde voltar (`Navigator.canPop`) —
/// aí o gesto normal já funciona.
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({required this.child, super.key});

  final Widget child;

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || canPop) return;
        final now = DateTime.now(); // clock-ok: janela de 2 s entre toques, não é data de negócio
        if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Toque em voltar de novo para sair'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      child: widget.child,
    );
  }
}
