import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/utils/year_month.dart';
import '../../accounts/presentation/account_form_screen.dart';
import '../../accounts/presentation/account_label.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../domain/due_info.dart';
import '../domain/month_situation.dart';
import '../domain/month_summary.dart';
import 'bill_payment_screen.dart';
import 'entry_filters_provider.dart';
import 'month_providers.dart';
import 'month_situation_widgets.dart' show cardSpendLabel;

const _tabular = [FontFeature.tabularFigures()];

/// A situação de relance virou tela (feat 0042): quanto há em cada conta, quanto
/// se deve em cada cartão (o mais perto de vencer primeiro) e o resumo do mês.
/// Lê os saldos **ao vivo**; a folha antiga mostrava um retrato do toque.
class SituationScreen extends ConsumerWidget {
  const SituationScreen({super.key, required this.month});

  static const String path = '/situacao';

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value;
    final balances = ref.watch(accountBalancesProvider).value;
    final rows = ref.watch(monthEntriesProvider(month)).value;

    Widget body() {
      if (accounts == null || balances == null) return const Center(child: CircularProgressIndicator());
      final situation = MonthSituation.from(
        accounts: accounts,
        balances: balances,
        summary: rows == null || rows.isEmpty ? null : MonthSummary.from(rows),
      );
      return _Content(situation: situation, month: month, today: ref.read(clockProvider)());
    }

    return Scaffold(
      // Sem o mês: saldos e dívidas são os de hoje; só o resumo abaixo é do mês (júri 1.0.3, S3).
      appBar: AppBar(title: const Text('Situação'), actions: const [BalancesEyeButton()]),
      body: DefaultTextStyle.merge(style: theme.textTheme.bodyLarge, child: body()),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.situation, required this.month, required this.today});

  final MonthSituation situation;
  final YearMonth month;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    void showOnly(Account account) {
      ref.read(entryFiltersProvider.notifier).setAccounts({account.id});
      context.pop();
    }

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Text(text, style: theme.textTheme.titleMedium),
    );

    // No tamanho do nome da linha (o padrão do trailing do ListTile é bem menor): o saldo é o
    // dado principal da tela (júri 1.0.3, S4).
    Widget money(int cents, {bool bold = false}) => MoneyText(
      cents,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontFeatures: _tabular,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
      ),
    );

    Widget row(String label, int cents, {VoidCallback? onTap, bool bold = false}) => ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      title: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null),
      trailing: money(cents, bold: bold),
      onTap: onTap,
    );

    // Cartões: o vencimento mais perto primeiro; sem vencimento cadastrado, no fim.
    final cards = [
      for (final c in situation.openCards) (data: c, due: DueInfo.of(dueDay: c.card.dueDay, today: today)),
    ]..sort((a, b) => (a.due.daysUntil ?? 1 << 20).compareTo(b.due.daysUntil ?? 1 << 20));

    final summary = situation.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Em conta', style: muted),
        money(situation.totalCents, bold: true).textStyled(theme.textTheme.headlineSmall),
        if (situation.openCardsCents > 0) ...[
          const SizedBox(height: 6),
          MoneyText(situation.openCardsCents, style: theme.textTheme.titleMedium, prefix: 'Faturas abertas '),
        ],
        heading('Seu dinheiro'),
        Text('Toque numa conta para ver só os lançamentos dela.', style: muted),
        for (final b in situation.accountBalances) ...[
          row(b.account.name, b.cents, onTap: () => showOnly(b.account)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => context.push(AccountFormScreen.editPath(b.account.id)),
              child: Text('Ajustar saldo de ${b.account.name}'),
            ),
          ),
        ],
        if (cards.isNotEmpty) heading('O que você deve'),
        for (final c in cards)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(cardTitle(c.data.card), style: theme.textTheme.titleSmall)),
                      money(c.data.openCents, bold: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (c.data.card.closingDay != null) 'fecha dia ${c.data.card.closingDay}',
                      if (c.due.daysUntil != null) 'vence dia ${c.data.card.dueDay}',
                      c.due.label,
                    ].join(' · '),
                    style: muted,
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => showOnly(c.data.card),
                        child: const Text('Ver lançamentos'),
                      ),
                      FilledButton(
                        onPressed: () => context.push(BillPaymentScreen.pathFor(c.data.card.id)),
                        child: const Text('Pagar fatura'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        heading('Resumo de ${month.label}'),
        row('Entradas', situation.incomeCents),
        row('Gastos no débito', summary?.debitExpenseCents ?? 0),
        for (final c in summary?.cards ?? const []) row(cardSpendLabel(c.card), c.cents),
      ],
    );
  }
}

extension on Widget {
  /// Aplica um estilo de texto ao redor (para o número grande do topo).
  Widget textStyled(TextStyle? style) => DefaultTextStyle.merge(style: style, child: this);
}
