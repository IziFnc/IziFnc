import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../entries/presentation/month_screen.dart';

/// Passo 5: concluído.
class ImportDoneStep extends StatelessWidget {
  const ImportDoneStep({super.key, required this.savedCount});

  final int savedCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('$savedCount lançamento(s) importado(s).'),
            const SizedBox(height: 24),
            FilledButton(
              // `go`, não `pop`: a importação é aberta pelo menu (que troca a tela), então
              // não há tela por baixo para desempilhar.
              onPressed: () => context.go(MonthScreen.path),
              child: const Text('Voltar para o mês'),
            ),
          ],
        ),
      ),
    );
  }
}
