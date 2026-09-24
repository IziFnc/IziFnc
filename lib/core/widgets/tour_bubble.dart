import 'package:flutter/material.dart';

import 'tour_step.dart';

/// O conteúdo de cada parada do tour: um cartão de verdade (não texto solto
/// sobre o véu escuro), com ícone, "N de M", título, mensagem e o botão para
/// seguir. Usado dentro do `TargetContent.builder` de cada `TourTarget`.
class TourBubble extends StatelessWidget {
  const TourBubble({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;

  /// 1-based: "1 de 8", não "0 de 8".
  final int stepNumber;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: colors.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(step.icon, size: 20, color: colors.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Text(
                  '$stepNumber de ${kTourSteps.length}',
                  style: textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(step.title, style: textTheme.titleMedium?.copyWith(color: colors.onSurface)),
            const SizedBox(height: 8),
            Text(step.message, style: textTheme.bodyMedium?.copyWith(color: colors.onSurface)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: onSkip, child: const Text('Pular o tour')),
                FilledButton(onPressed: onNext, child: Text(step.buttonLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
