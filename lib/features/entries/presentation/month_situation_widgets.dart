import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/year_month.dart';
import '../../accounts/presentation/account_form_screen.dart';
import '../../accounts/presentation/account_label.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../import/presentation/import_screen.dart';
import '../../settings/presentation/data_settings_screen.dart';
import '../domain/month_situation.dart';
import 'entry_filters_provider.dart';
import 'entry_form_screen.dart';
import 'month_providers.dart';

const _tabular = [FontFeature.tabularFigures()];

/// "Gastos no cartão Amazon" (sem repetir "cartão" quando o nome já diz).
String cardSpendLabel(Account card) {
  final title = cardTitle(card); // "Cartão Amazon" ou o próprio "Cartão Bradesco"
  return 'Gastos no ${title[0].toLowerCase()}${title.substring(1)}';
}

/// A situação de relance no topo da home: quanto há nas contas, quanto se deve
/// nos cartões e o que entrou e saiu no mês. Tocar abre os detalhes
/// ([showSituationSheet]). Substitui os três blocos que ocupavam quase metade
/// da tela (saldos, mês e resumo).
class SituationCard extends StatelessWidget {
  const SituationCard({
    super.key,
    required this.situation,
    required this.monthLoaded,
    required this.onTap,
  });

  final MonthSituation situation;

  /// Falso enquanto os lançamentos do mês ainda carregam (não mostra "Entrou R$ 0").
  final bool monthLoaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bold = theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontFeatures: _tabular);

    Widget line(String label, int cents, {TextStyle? style}) => Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(Formatters.money(cents), style: style ?? const TextStyle(fontFeatures: _tabular)),
      ],
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    line('Em conta', situation.totalCents, style: bold),
                    if (situation.openCardsCents > 0) ...[
                      const SizedBox(height: 2),
                      line('Faturas abertas', situation.openCardsCents),
                    ],
                    if (monthLoaded) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Entrou ${Formatters.money(situation.incomeCents)} · '
                        'Gastou ${Formatters.money(situation.spentCents)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Os detalhes por trás do [SituationCard]: cada conta e cada fatura (tocar
/// filtra a lista por ela) e o resumo do mês.
Future<void> showSituationSheet(
  BuildContext context, {
  required MonthSituation situation,
  required YearMonth month,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SituationSheet(situation: situation, month: month),
);

class _SituationSheet extends ConsumerWidget {
  const _SituationSheet({required this.situation, required this.month});

  final MonthSituation situation;
  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    void showOnly(Account account) {
      ref.read(entryFiltersProvider.notifier).setAccounts({account.id});
      Navigator.of(context).pop();
    }

    Widget section(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    // Linha de 48 dp no mínimo (ListTile), tocável quando leva a um filtro.
    Widget row(String label, int cents, {VoidCallback? onTap, bool bold = false}) => ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      dense: false,
      title: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null),
      trailing: Text(
        Formatters.money(cents),
        // No tamanho do nome da linha (o padrão do trailing é bem menor).
        style: theme.textTheme.bodyLarge?.copyWith(
          fontFeatures: _tabular,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );

    final summary = situation.summary;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Situação de ${month.label}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'Toque numa conta ou fatura para ver só os lançamentos dela.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            section('Contas (saldo de hoje)'),
            for (final b in situation.accountBalances)
              row(b.account.name, b.cents, onTap: () => showOnly(b.account)),
            if (situation.accountBalances.length > 1) row('Total em contas', situation.totalCents, bold: true),
            if (situation.openCards.isNotEmpty) ...[
              section('Faturas abertas'),
              for (final c in situation.openCards)
                row(cardTitle(c.card), c.openCents, onTap: () => showOnly(c.card)),
            ],
            section('Resumo de ${month.label}'),
            row('Entradas', situation.incomeCents),
            row('Gastos no débito', summary?.debitExpenseCents ?? 0),
            for (final c in summary?.cards ?? const []) row(cardSpendLabel(c.card), c.cents),
          ],
        ),
      ),
    );
  }
}

/// Para quem acabou de cadastrar a conta e ainda não lançou nada: o que fazer
/// agora, em vez de uma lista vazia. Some sozinho no primeiro lançamento.
class FirstStepsCard extends StatelessWidget {
  const FirstStepsCard({super.key, required this.hasCard});

  final bool hasCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Primeiros passos', style: theme.textTheme.titleMedium),
            ),
            step(
              Icons.tune,
              'Ajustar o saldo',
              'Diga quanto há hoje em cada conta.',
              () => context.go(AccountsScreen.path),
            ),
            if (!hasCard)
              step(
                Icons.credit_card,
                'Cadastrar um cartão',
                'Para lançar compras no crédito.',
                () => context.push(AccountFormScreen.newPath),
              ),
            step(
              Icons.upload_file_outlined,
              'Importar a sua planilha',
              'Traz os lançamentos que você já tem.',
              () => context.go(ImportScreen.path),
            ),
            step(
              Icons.add,
              'Lançar o primeiro gasto',
              'Direto pelo botão +.',
              () => context.push(EntryFormScreen.newPath),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Faz tempo sem backup": uma linha, dispensável. Leva a Configurações › Dados.
class BackupNotice extends ConsumerWidget {
  const BackupNotice({super.key, required this.lastBackup});

  /// Nulo = nunca fez.
  final DateTime? lastBackup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final last = lastBackup;
    final text = last == null
        ? 'Você ainda não salvou um backup dos seus dados.'
        : 'Faz ${DateTime.now().difference(last).inDays} dias que você não salva um backup.';
    final color = theme.colorScheme.onSecondaryContainer;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.backup_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color))),
          TextButton(
            onPressed: () => context.push(DataSettingsScreen.path),
            child: const Text('Salvar'),
          ),
          IconButton(
            tooltip: 'Dispensar',
            icon: Icon(Icons.close, color: color),
            onPressed: ref.read(backupNoticeDismissedProvider.notifier).dismiss,
          ),
        ],
      ),
    );
  }
}
