import 'package:flutter/material.dart';

/// Passo 2: qual aba (mês) importar.
class ImportPickSheetStep extends StatelessWidget {
  const ImportPickSheetStep({
    super.key,
    required this.sheetNames,
    required this.banner,
    required this.busy,
    required this.onPick,
  });

  final List<String> sheetNames;
  final Widget banner;
  final bool busy;
  final void Function(String name) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A chamada ao LLM pode levar vários segundos (e mais, se o provedor
        // estiver sobrecarregado e houver nova tentativa) — sem isto a tela
        // fica idêntica e parece que o toque não pegou.
        if (busy) const LinearProgressIndicator(),
        banner,
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Qual aba (mês) importar?'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            busy
                ? 'Localizando as tabelas… pode levar alguns segundos.'
                : 'Este passo precisa de internet — um serviço externo ajuda a '
                      'localizar as tabelas na aba.',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final name in sheetNames)
                ListTile(
                  title: Text(name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy ? null : () => onPick(name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
