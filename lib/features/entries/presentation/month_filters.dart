import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../accounts/presentation/account_label.dart';
import '../domain/entry_filters.dart';
import 'entry_filters_provider.dart';

/// Filtros e busca da lista do mês (feat 0022).
///
/// Na home ficam **fora do caminho**: a busca é uma lupa na barra e o resto mora
/// na folha "Filtrar e ordenar". Antes eram um campo de busca e uma fileira de
/// chips fixos acima da lista, que junto do resto empurravam o primeiro
/// lançamento para o meio da tela.

Future<void> showFilterSheet(BuildContext context, List<Account> accounts) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FilterSheet(accounts: accounts),
    );

/// O botão de filtro da barra, com o número de filtros ligados.
class FilterButton extends ConsumerWidget {
  const FilterButton({super.key, required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(entryFiltersProvider.select((f) => f.activeCount));
    return IconButton(
      tooltip: 'Filtrar e ordenar',
      onPressed: () => showFilterSheet(context, accounts),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.tune),
      ),
    );
  }
}

/// O campo de busca que ocupa o lugar do título da barra enquanto se procura.
class SearchTitleField extends ConsumerStatefulWidget {
  const SearchTitleField({super.key});

  @override
  ConsumerState<SearchTitleField> createState() => _SearchTitleFieldState();
}

class _SearchTitleFieldState extends ConsumerState<SearchTitleField> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(entryFiltersProvider).query,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Trocar de mês (ou "Limpar filtros") zera a busca por fora: o campo acompanha.
    ref.listen(entryFiltersProvider.select((f) => f.query), (_, query) {
      if (_controller.text != query) _controller.text = query;
    });
    return TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'Buscar lançamentos',
        border: InputBorder.none,
      ),
      onChanged: ref.read(entryFiltersProvider.notifier).setQuery,
    );
  }
}

/// Escolher o tipo, contas e cartões (várias) e a ordem da lista.
class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key, required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(entryFiltersProvider);
    final controller = ref.read(entryFiltersProvider.notifier);
    final theme = Theme.of(context);

    void toggle(int id, bool on) {
      final next = {...filters.accountIds};
      on ? next.add(id) : next.remove(id);
      controller.setAccounts(next);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in EntryKindFilter.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: filters.kind == kind,
                    onSelected: (_) => controller.setKind(kind),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Contas e cartões', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              filters.accountIds.isEmpty
                  ? 'Todas. Toque para ver só algumas.'
                  : '${filters.accountIds.length} escolhida(s).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in accounts)
                  FilterChip(
                    avatar: Icon(accountIcon(a), size: 18),
                    label: Text(accountLabel(a, all: accounts)),
                    selected: filters.accountIds.contains(a.id),
                    onSelected: (on) => toggle(a.id, on),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Ordenar por', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<EntrySort>(
              segments: [
                for (final sort in EntrySort.values)
                  ButtonSegment(value: sort, label: Text(sort.label)),
              ],
              selected: {filters.sort},
              onSelectionChanged: (s) => controller.setSort(s.single),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: filters.isActive ? controller.clearFilters : null,
                  child: const Text('Limpar filtros'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Concluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
