import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../accounts/presentation/account_form_screen.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../domain/build_import_plan.dart';
import '../domain/parsed_row.dart';
import 'bank_mapping_tile.dart';

/// Passo 3: para qual conta ou cartão vai cada (banco, tipo) da aba.
class ImportMapBanksStep extends ConsumerWidget {
  const ImportMapBanksStep({
    super.key,
    required this.banner,
    required this.fallbackBanner,
    required this.pairs,
    required this.mapped,
    required this.skipped,
    required this.busy,
    required this.onSelect,
    required this.onSkip,
    required this.onContinue,
    this.problems = const [],
  });

  final Widget banner;
  final Widget fallbackBanner;
  final List<(String banco, SourceTipo tipo)> pairs;

  /// Chave de mapeamento (banco|tipo) -> conta escolhida; quem muda é a tela.
  final Map<String, int> mapped;
  final Set<String> skipped;
  final bool busy;
  final void Function(String banco, SourceTipo tipo, int accountId) onSelect;
  final void Function(String banco, SourceTipo tipo) onSkip;
  final VoidCallback onContinue;

  /// Por que linhas da aba foram descartadas (mostradas quando nenhuma sobrou).
  final List<String> problems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    // Cada banco precisa de uma decisão (conta ou "não importar"), e pelo menos
    // um tem de entrar: assim dá para importar só uma parte da aba.
    final canContinue = canContinueMapping(
      keys: [for (final (banco, tipo) in pairs) bankMappingKey(banco, tipo)],
      mapped: mapped,
      skipped: skipped,
    );

    if (pairs.isEmpty) return _NothingToImport(banner: banner, problems: problems);

    return Column(
      children: [
        banner,
        fallbackBanner,
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Para qual conta ou cartão vai cada um? '
            'Marque "Não importar" nos que quiser deixar de fora.',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (banco, tipo) in pairs)
                BankMappingTile(
                  banco: banco,
                  tipo: tipo,
                  accounts: accounts,
                  selected: mapped[bankMappingKey(banco, tipo)],
                  skipped: skipped.contains(bankMappingKey(banco, tipo)),
                  onSelect: (id) => onSelect(banco, tipo, id),
                  onSkip: () => onSkip(banco, tipo),
                  onCreateAccount: () async {
                    await context.push(AccountFormScreen.newPath);
                  },
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              onPressed: canContinue && !busy ? onContinue : null,
              child: const Text('Continuar'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nenhuma linha da aba sobreviveu à leitura (feat 0049, achado F1): em vez de uma
/// lista vazia com o botão desligado, diz o que houve e o que conferir.
class _NothingToImport extends StatelessWidget {
  const _NothingToImport({required this.banner, required this.problems});

  final Widget banner;
  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        banner,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Nenhuma linha desta aba pôde ser importada', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'O app achou as tabelas, mas não conseguiu ler as linhas. Confira se as datas são datas de verdade '
                '(não texto), se o valor e o banco estão preenchidos e se o tipo é Débito ou Crédito. '
                'Volte e escolha outra aba, ou ajuste a planilha.',
              ),
              if (problems.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Exemplos do que foi descartado', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                for (final message in problems.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(message, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (problems.length > 3) Text('e mais ${problems.length - 3}.'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
