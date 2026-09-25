import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../features/settings/presentation/settings_providers.dart';
import '../database/repositories.dart';
import 'tour_bubble.dart';
import 'tour_step.dart';

/// Liga (padrão) ou desliga o tour guiado. O véu que ele desenha é modal
/// (bloqueia toque na tela toda até a pessoa tocar em algum botão da bolha),
/// então testes de widget que só querem passar por uma destas telas — sem
/// testar o tour em si — desligam este provider (`overrideWithValue(false)`).
final tourEnabledProvider = Provider<bool>((ref) => true);

/// Embrulha [child] e, quando ele é a parada atual do tour guiado (feat 0026)
/// e [ready] é verdadeiro, mostra a bolha apontando para ele: a tela escurece,
/// um recorte destaca o widget e um cartão explica o que ele faz, com "N de M"
/// e um botão para seguir (que já leva para a próxima parada, se for outra
/// tela). Ver [kTourSteps] para o roteiro completo e [TourAnchor] para a
/// posição de cada parada.
class TourTarget extends ConsumerStatefulWidget {
  const TourTarget({required this.anchor, required this.child, this.ready = true, super.key});

  final TourAnchor anchor;
  final Widget child;

  /// Falso quando o alvo existe mas ainda não faz sentido destacá-lo (ex.: a
  /// situação da home antes dos saldos carregarem, ou "Escolher arquivo" da
  /// importação desabilitado pelo checklist "Antes de começar"). A bolha só
  /// aparece quando isto vira verdadeiro.
  final bool ready;

  @override
  ConsumerState<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends ConsumerState<TourTarget> {
  final _targetKey = GlobalKey();

  /// Verdadeiro enquanto ESTA instância já tem uma bolha aberta — evita abrir
  /// de novo a cada rebuild. Não é uma trava permanente: se "Ver o tour de
  /// novo" reiniciar o passo com o widget ainda montado (ex.: a home, que
  /// sobrevive a idas e vindas pelo menu), a bolha deve poder abrir de novo
  /// sem precisar recriar a tela.
  bool _open = false;

  void _maybeShow(int currentStep) {
    if (_open || !widget.ready || currentStep != widget.anchor.index) return;
    if (_targetKey.currentContext == null) return;
    _open = true;
    _show(currentStep);
  }

  void _show(int stepIndex) {
    final step = kTourSteps[stepIndex];
    final colors = Theme.of(context).colorScheme;
    // Um campo com foco automático (ex.: "Valor" no lançamento) pode abrir o
    // teclado por cima da bolha assim que a tela monta — tirar o foco antes
    // de mostrar evita que isso aconteça.
    FocusManager.instance.primaryFocus?.unfocus();
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: step.anchor.name,
          keyTarget: _targetKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: step.align,
              builder: (context, controller) => TourBubble(
                step: step,
                stepNumber: stepIndex + 1,
                onNext: controller.next,
                onSkip: controller.skip,
              ),
            ),
          ],
        ),
      ],
      colorShadow: colors.scrim,
      // O padrão do pacote (80%) some quase tudo no tema escuro: por cima de
      // um fundo já quase preto, um véu preto a 80% deixa até o texto que
      // explica o próximo passo ilegível. No claro, o fundo claro sobra
      // brilho suficiente mesmo dimmed — só o escuro precisa de um véu mais
      // fraco (achado no celular real, feat 0026).
      opacityShadow: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.8,
      // Sem o pulso contínuo: ele nunca "assenta" (a animação se repete para
      // sempre), o que travaria qualquer teste que use `pumpAndSettle` depois
      // de abrir uma destas telas.
      pulseEnable: false,
      // O pacote desenha o próprio texto "SKIP" solto num canto por padrão;
      // a bolha já tem "Pular o tour", então esse extra só sobra por cima de
      // outro botão (achado no celular real, feat 0026).
      hideSkip: true,
      onFinish: () => _advance(step),
      onSkip: () {
        _skipTour();
        return true;
      },
    ).show(context: context);
  }

  void _advance(TourStep step) {
    _open = false;
    ref.read(settingsRepositoryProvider).advanceTour();
    final next = step.nextRoute;
    if (next != null) {
      step.pushNext ? context.push(next) : context.go(next);
    }
  }

  void _skipTour() {
    _open = false;
    ref.read(settingsRepositoryProvider).skipTour();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(tourEnabledProvider);
    final step = enabled ? ref.watch(tourStepProvider).value : null;
    if (step != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeShow(step);
      });
    }
    return KeyedSubtree(key: _targetKey, child: widget.child);
  }
}
