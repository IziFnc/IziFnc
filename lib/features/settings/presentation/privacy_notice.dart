import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/repositories.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import '../domain/privacy_text.dart';
import 'privacy_providers.dart';
import 'privacy_screen.dart';
import 'settings_providers.dart';

/// Aviso curto na tela inicial: "seus dados ficam só neste aparelho". Aparece
/// uma vez por versão do texto de privacidade e some ao dispensar ou ao abrir a
/// política. Não é o consentimento (esse vem antes do envio à IA): nada sai do
/// aparelho sem ele.
class PrivacyNotice extends ConsumerWidget {
  const PrivacyNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(privacyNoticeVersionProvider).value;
    // Sem resposta ainda (carregando), não pisca o aviso.
    if (seen == null || seen >= kPrivacyVersion) return const SizedBox.shrink();

    // O tour guiado manda: o aviso espera ele acabar (ou ser pulado), para não
    // empurrar os alvos das bolhas para fora da tela nem mexer no layout na hora
    // em que uma bolha mede o alvo. Quem nunca fez o tour vê a política em
    // Configurações > Geral > Privacidade e na folha de autorização da IA.
    if (ref.watch(tourEnabledProvider)) {
      final step = ref.watch(tourStepProvider).value;
      if (step == null || step < kTourSteps.length) return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final color = theme.colorScheme.onSecondaryContainer;
    final repo = ref.read(settingsRepositoryProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(Icons.lock_outline, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Seus dados ficam neste aparelho, salvo o texto que você mandar à IA na importação.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
                // Embaixo do texto (com letra grande não aperta a frase) e na cor
                // do aviso: a cor padrão do botão sumia no alto contraste.
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    textStyle: const TextStyle(decoration: TextDecoration.underline),
                  ),
                  onPressed: () async {
                    await repo.markPrivacyNoticeSeen(kPrivacyVersion);
                    if (context.mounted) context.push(PrivacyScreen.path);
                  },
                  child: const Text('Privacidade'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dispensar',
            icon: Icon(Icons.close, color: color),
            onPressed: () => repo.markPrivacyNoticeSeen(kPrivacyVersion),
          ),
        ],
      ),
    );
  }
}
