import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/repositories.dart';
import '../../../core/utils/clock.dart';
import '../../import/data/ai_slots_store.dart';
import '../../import/data/llm_slot.dart';
import '../../import/presentation/import_providers.dart';
import '../domain/privacy_text.dart';
import 'privacy_screen.dart';

/// A chave do destinatário de um slot, como guardada na autorização:
/// `groq`, `anthropic` ou `custom:<host>`.
String consentKeyOf(LlmSlot slot) => switch (slot.kind) {
  LlmServiceKind.groq => 'groq',
  LlmServiceKind.anthropic => 'anthropic',
  LlmServiceKind.openaiCompatible => 'custom:${Uri.tryParse(slot.baseUrl?.trim() ?? '')?.host ?? ''}',
};

/// Garante a autorização de envio à IA antes de a importação mandar o texto da
/// planilha. Já autorizada para todos os serviços configurados (e na versão
/// atual do texto de privacidade)? Segue sem perguntar. Senão abre a folha
/// "Antes de continuar" e só segue se a pessoa aceitar.
///
/// Devolve `true` quando pode enviar. Sem nenhuma IA configurada, devolve
/// `true`: não há destinatário, e o fluxo mostra o próprio erro.
Future<bool> ensureAiConsent(BuildContext context, WidgetRef ref) async {
  final slots = await storedSlotsResolver(ref.read(aiSlotsStoreProvider))();
  final keys = {for (final s in slots) consentKeyOf(s)};
  if (keys.isEmpty) return true;

  final repo = ref.read(settingsRepositoryProvider);
  if ((await repo.aiConsent()).covers(keys)) return true;
  if (!context.mounted) return false;

  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AiConsentSheet(serviceKeys: keys.toList()),
  );
  if (accepted != true) return false;
  await repo.grantAiConsent(keys, ref.read(clockProvider)(), version: kPrivacyVersion);
  return true;
}

/// A folha de autorização: o que vai, para quem e o que não vai.
class AiConsentSheet extends StatelessWidget {
  const AiConsentSheet({super.key, required this.serviceKeys});

  /// Os destinatários, na ordem em que podem receber o texto (Principal primeiro).
  final List<String> serviceKeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Antes de continuar', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(kConsentWhatGoes),
            const SizedBox(height: 12),
            for (final key in serviceKeys)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.cloud_upload_outlined, size: 18),
                    ),
                    Expanded(child: Text(consentServiceLine(key), style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const Text(kConsentWhatStays),
            const SizedBox(height: 8),
            Text(
              'Você pode revogar quando quiser, em Configurações > Inteligência artificial. A Reserva só recebe o texto se a Principal falhar.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            TextButton(
              onPressed: () => context.push(PrivacyScreen.path),
              child: const Text('Ler a política de privacidade completa'),
            ),
            const SizedBox(height: 8),
            // Largura toda: alvo de toque grande e os dois botões alinhados.
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Aceitar e continuar'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Agora não'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
