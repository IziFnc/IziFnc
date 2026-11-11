import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories.dart';
import '../../../core/utils/formatters.dart';
import '../domain/ai_consent.dart';
import 'privacy_providers.dart';

/// Mostra a autorização de envio à IA e deixa revogá-la. Fica na tela de IA e
/// na tela de privacidade.
class AiConsentCard extends ConsumerWidget {
  const AiConsentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final consent = ref.watch(aiConsentProvider).value ?? AiConsent.none;
    final granted = consent.granted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Autorização de envio à IA', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              granted
                  ? 'Última autorização em ${Formatters.date(consent.at!)} para: ${_names(consent.services)}.'
                  : 'Ainda não autorizada. O app pergunta antes do primeiro envio do texto da planilha.',
            ),
            if (granted)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.block),
                  label: const Text('Revogar autorização'),
                  onPressed: () async {
                    await ref.read(settingsRepositoryProvider).revokeAiConsent();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Autorização revogada. A importação pedirá de novo.')),
                      );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _names(Set<String> keys) => [
    for (final k in (keys.toList()..sort()))
      switch (k) {
        'groq' => 'Groq',
        'anthropic' => 'Anthropic',
        _ => k.startsWith('custom:') ? k.substring(7) : k,
      },
  ].join(', ');
}
