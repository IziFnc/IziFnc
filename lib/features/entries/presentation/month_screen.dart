import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/year_month.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import '../../accounts/presentation/account_form_screen.dart';
import '../../accounts/presentation/account_label.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../settings/presentation/data_settings_screen.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/competence.dart';
import '../domain/entry_filters.dart';
import '../domain/entry_type.dart';
import '../domain/entry_with_account.dart';
import '../domain/month_situation.dart';
import '../domain/month_summary.dart';
import 'entry_filters_provider.dart';
import 'entry_form_screen.dart';
import 'month_filters.dart';
import 'month_providers.dart';
import 'month_situation_widgets.dart';

/// Home: os lançamentos de um mês de competência e a situação de relance.
///
/// O topo é enxuto de propósito (feat 0022): o mês e as ações na barra e **um**
/// cartão de situação; o detalhe (cada conta, cada fatura, o resumo do mês) fica
/// numa folha que abre ao tocar no cartão. O que interessa é a lista.
class MonthScreen extends ConsumerStatefulWidget {
  const MonthScreen({super.key});

  static const String path = '/';

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final startDay = ref.watch(monthStartDayProvider);
    final query = ref.watch(entryFiltersProvider.select((f) => f.query));
    final filtersController = ref.read(entryFiltersProvider.notifier);
    final select = ref.read(selectedMonthProvider.notifier).select;

    // Os filtros valem para um mês. Ao mudar de mês — pelas setas ou porque um
    // lançamento novo levou a tela para outro — voltam ao normal, senão um
    // filtro esquecido poderia esconder o lançamento que acabou de ser salvo.
    ref.listen(selectedMonthProvider, (_, _) {
      filtersController.reset();
      if (_searching) setState(() => _searching = false);
    });

    final list = accounts.value;
    final start = startDay.value;
    final hasAccounts = list != null && list.isNotEmpty && start != null;
    final month = hasAccounts
        ? (ref.watch(selectedMonthProvider) ?? competenceOf(DateTime.now(), start))
        : null;
    final searchOpen = _searching || query.isNotEmpty;

    return Scaffold(
      appBar: hasAccounts
          ? AppBar(
              titleSpacing: 0,
              title: searchOpen
                  ? const SearchTitleField()
                  : _MonthTitle(
                      month: month!,
                      onPrevious: () => select(month.previous()),
                      onNext: () => select(month.next()),
                    ),
              actions: [
                if (searchOpen)
                  IconButton(
                    tooltip: 'Fechar busca',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      filtersController.setQuery('');
                      setState(() => _searching = false);
                    },
                  )
                else
                  IconButton(
                    tooltip: 'Buscar',
                    icon: const Icon(Icons.search),
                    onPressed: () => setState(() => _searching = true),
                  ),
                TourTarget(
                  anchor: TourAnchor.homeFilters,
                  child: FilterButton(accounts: list),
                ),
              ],
            )
          : AppBar(title: const Text('IziFnc')),
      drawer: const AppDrawer(current: AppDestination.home),
      body: switch ((accounts, startDay)) {
        (AsyncData(), AsyncData()) when !hasAccounts => const _NoAccounts(),
        (AsyncData(), AsyncData()) => _MonthBody(accounts: list!, month: month!),
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          Center(child: Text('Erro ao carregar: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: switch (accounts) {
        AsyncData(value: final list) when list.isNotEmpty =>
          FloatingActionButton(
            tooltip: 'Novo lançamento',
            onPressed: () => context.push(EntryFormScreen.newPath),
            child: const Icon(Icons.add),
          ),
        _ => null,
      },
    );
  }
}

/// "‹ Setembro de 2026 ›" no lugar do título da barra. Só o **texto** encolhe
/// quando falta espaço; as setas mantêm o alvo de toque de 48 dp.
class _MonthTitle extends StatelessWidget {
  const _MonthTitle({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final YearMonth month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(month.title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _MonthBody extends ConsumerWidget {
  const _MonthBody({required this.accounts, required this.month});

  final List<Account> accounts;
  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(monthEntriesProvider(month));
    final balances = ref.watch(accountBalancesProvider).value;
    final filters = ref.watch(entryFiltersProvider);
    final filtersController = ref.read(entryFiltersProvider.notifier);
    final entryCount = ref.watch(entryCountProvider).value;
    final lastBackup = ref.watch(lastBackupProvider);
    final noticeDismissed = ref.watch(backupNoticeDismissedProvider);

    final rows = entries.value;
    final situation = balances == null
        ? null
        : MonthSituation.from(
            accounts: accounts,
            balances: balances,
            summary: rows == null || rows.isEmpty ? null : MonthSummary.from(rows),
          );

    // Lembrete de backup: nunca feito (só depois de a pessoa ter uma base de
    // lançamentos que valha guardar) ou vencido. Dispensável.
    final last = lastBackup.value;
    final showBackupNotice =
        !noticeDismissed &&
        lastBackup.hasValue &&
        (last == null
            ? (entryCount ?? 0) >= 10
            : DateTime.now().difference(last) > DataSettingsScreen.staleAfter);

    // Um scroll só: o topo rola junto com a lista.
    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // espaço do FAB
      children: [
        if (showBackupNotice) BackupNotice(lastBackup: last),
        if (situation != null)
          TourTarget(
            anchor: TourAnchor.situationCard,
            child: SituationCard(
              situation: situation,
              monthLoaded: rows != null,
              onTap: () => showSituationSheet(context, situation: situation, month: month),
            ),
          ),
        ...switch (entries) {
          AsyncData(value: final rows) when rows.isEmpty => [
            if (entryCount == 0)
              FirstStepsCard(hasCard: accounts.any((a) => a.kind.isCard))
            else
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nenhum lançamento em ${month.label}.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          AsyncData(value: final rows) => [
            ...switch (applyFilters(rows, filters)) {
              final shown => [
                if (filters.isActive)
                  _FilterStatus(
                    shown: shown.length,
                    total: rows.length,
                    onClear: filtersController.clearFilters,
                  ),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nenhum lançamento com esses filtros.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final row in shown) _EntryTile(row: row),
              ],
            },
          ],
          AsyncError(:final error) => [Center(child: Text('Erro: $error'))],
          _ => [const Center(child: CircularProgressIndicator())],
        },
      ],
    );
  }
}

/// "Mostrando N de M lançamentos", só quando há filtro, com o atalho para limpar.
class _FilterStatus extends StatelessWidget {
  const _FilterStatus({
    required this.shown,
    required this.total,
    required this.onClear,
  });

  final int shown;
  final int total;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text('Mostrando $shown de $total lançamento(s)')),
          TextButton(onPressed: onClear, child: const Text('Limpar filtros')),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.row});

  final EntryWithAccount row;

  @override
  Widget build(BuildContext context) {
    final EntryWithAccount(:entry, :account, :toAccount) = row;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final amount = Formatters.money(entry.amountCents);

    // Transferência "Bradesco → C6" e pagamento "Bradesco → fatura Amazon":
    // valor neutro (não é gasto). Ajuste: sinal explícito, também neutro.
    final (icon, where, shownAmount, color) = switch (entry.type) {
      EntryType.transfer => (
        Icons.swap_horiz,
        '${accountLabel(account)} → ${toAccount == null ? '?' : accountLabel(toAccount)}',
        amount,
        colors.onSurfaceVariant,
      ),
      EntryType.billPayment => (
        Icons.receipt_long_outlined,
        '${accountLabel(account)} → fatura ${toAccount?.name ?? '?'}',
        amount,
        colors.onSurfaceVariant,
      ),
      EntryType.adjustmentIncrease => (
        Icons.tune,
        accountLabel(account),
        '+ $amount',
        colors.onSurfaceVariant,
      ),
      EntryType.adjustmentDecrease => (
        Icons.tune,
        accountLabel(account),
        '− $amount',
        colors.onSurfaceVariant,
      ),
      EntryType.income => (
        accountIcon(account),
        accountLabel(account),
        '+ $amount',
        colors.primary,
      ),
      EntryType.expense => (
        accountIcon(account),
        accountLabel(account),
        amount,
        null,
      ),
    };

    return ListTile(
      leading: Icon(icon, color: colors.onSurfaceVariant),
      title: Text(entry.description),
      subtitle: Text(
        [Formatters.dayMonth(entry.date), where, ?entry.note].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // O valor é o que se procura na lista: no tamanho do texto do nome (o padrão
      // do trailing era ~11 sp) e em negrito leve.
      trailing: Text(
        shownAmount,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: () => context.push(EntryFormScreen.editPath(entry.id)),
    );
  }
}

class _NoAccounts extends StatelessWidget {
  const _NoAccounts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Cadastre sua primeira conta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Conta corrente ou cartão. Os lançamentos vão para ela.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TourTarget(
              anchor: TourAnchor.accountsAdd,
              child: FilledButton(
                onPressed: () => context.push(AccountFormScreen.newPath),
                child: const Text('Cadastrar conta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
