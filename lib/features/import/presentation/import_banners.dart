import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../settings/presentation/ai_settings_screen.dart';

/// Erro atual da importação, em português, com o detalhe técnico embaixo.
class ImportErrorBanner extends StatelessWidget {
  const ImportErrorBanner({
    super.key,
    required this.error,
    required this.detail,
    required this.missingKey,
  });

  final String? error;
  final String? detail;

  /// O erro é falta de chave de IA: oferece ir configurar.
  final bool missingKey;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final detail = this.detail;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText(
                'Detalhe técnico: $detail',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // Falta de chave não é falha do provedor: leva direto a quem resolve.
          if (missingKey)
            TextButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Configurar chave'),
              onPressed: () => context.push(AiSettingsScreen.path),
            ),
        ],
      ),
    );
  }
}

/// Avisa que a reserva respondeu no lugar do provedor principal — a reserva
/// costuma ser paga, então isso não pode acontecer em silêncio.
class ImportFallbackBanner extends StatelessWidget {
  const ImportFallbackBanner({super.key, required this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    if (note == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.onTertiaryContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: TextStyle(color: colors.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
