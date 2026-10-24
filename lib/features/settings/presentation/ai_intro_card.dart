import 'package:flutter/material.dart';

class AiIntroCard extends StatelessWidget {
  const AiIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSecondaryContainer;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    // O app não vem com chave nenhuma: sem configurar aqui, a
                    // importação não funciona. A frase diz isso logo de cara.
                    'Para importar uma planilha você precisa de uma chave de IA. '
                    'A Groq tem plano grátis: crie a chave em console.groq.com/keys '
                    'e cole em Principal.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            Theme(
              // Sem as linhas divisórias que o ExpansionTile põe por padrão.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  'O que sai do aparelho?',
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
                iconColor: color,
                collapsedIconColor: color,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A IA só serve para achar onde ficam as tabelas: vão apenas os '
                    'textos dos cabeçalhos. Valores e datas nunca saem do aparelho, e '
                    'as chaves ficam guardadas só nele.\n\n'
                    'A Reserva é opcional: só é chamada se a Principal falhar. O botão '
                    'Testar envia uma mensagem mínima e só roda quando você toca nele.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
