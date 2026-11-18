import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/formatters.dart';

/// Como os valores aparecem quando escondidos.
const String kHiddenMoney = 'R\$ ••••';

/// Valores escondidos ao abrir o app (feat 0048). Os testes de tela que procuram
/// números sobrescrevem isto com `false`; o app de verdade começa escondido.
final balancesHiddenAtStartProvider = Provider<bool>((ref) => true);

/// O "olhinho" dos apps de banco: esconde saldos e totais (Em conta, faturas
/// abertas, saldo por conta, resumo do mês). **Só vale enquanto o app está
/// aberto**: a cada abertura volta a começar escondido, sem gravar nada no
/// banco (sem migração) nem no backup. Os valores de cada lançamento e os campos
/// de digitação nunca são escondidos.
class BalancesHidden extends Notifier<bool> {
  @override
  bool build() => ref.watch(balancesHiddenAtStartProvider);

  void toggle() => state = !state;
}

final balancesHiddenProvider = NotifierProvider<BalancesHidden, bool>(BalancesHidden.new);

/// Um valor em reais que respeita o olhinho: "R$ ••••" quando escondido (com
/// rótulo falado "valor oculto" para o leitor de tela).
class MoneyText extends ConsumerWidget {
  const MoneyText(this.cents, {super.key, this.style, this.prefix = '', this.suffix = '', this.textAlign});

  final int cents;
  final TextStyle? style;

  /// Texto antes e depois do valor (ex.: "Faturas abertas ", " em aberto"); continuam quando escondido.
  final String prefix;
  final String suffix;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(balancesHiddenProvider);
    final text = hidden ? kHiddenMoney : Formatters.money(cents);
    final child = Text('$prefix$text$suffix', style: style, textAlign: textAlign);
    if (!hidden) return child;
    return Semantics(label: '${prefix}valor oculto$suffix', excludeSemantics: true, child: child);
  }
}

/// O botão do olhinho: mostra ou esconde os saldos e totais.
class BalancesEyeButton extends ConsumerWidget {
  const BalancesEyeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(balancesHiddenProvider);
    return IconButton(
      tooltip: hidden ? 'Mostrar valores' : 'Ocultar valores',
      icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => ref.read(balancesHiddenProvider.notifier).toggle(),
    );
  }
}
