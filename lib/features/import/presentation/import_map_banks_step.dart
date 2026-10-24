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
