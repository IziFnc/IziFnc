import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/money_text.dart';
import '../../accounts/presentation/account_label.dart';
import '../domain/month_panel.dart';
import '../domain/month_situation.dart';

const _tabular = [FontFeature.tabularFigures()];

/// O painel no topo da tela inicial (feat 0050), no lugar do cartão de números: quanto
/// há em conta (com o olhinho), o mês em duas barras (entrou e gastou, em percentual)
/// e o vencimento de cartão mais próximo. Tocar abre a tela Situação. Funciona com os
/// valores escondidos: barras, percentuais e dias continuam inteiros.
///
/// Resultado do Ateliê de 2026-11-17 (proposta B enxuta com a frase de A).
class MonthPanelCard extends ConsumerWidget {
  const MonthPanelCard({
    super.key,
    required this.situation,
    required this.monthLoaded,
    required this.onTap,
  });

  final MonthSituation situation;

  /// Falso enquanto os lançamentos do mês ainda carregam (as barras esperam).
  final bool monthLoaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hidden = ref.watch(balancesHiddenProvider);
    final panel = MonthPanel.from(
      situation: situation,
      today: ref.watch(clockProvider)(),
    );

    // A fala do leitor de tela: o mesmo que se vê, sem ler os reais quando escondidos.
    final spoken = [
      hidden
          ? 'Em conta, valor oculto'
          : 'Em conta ${Formatters.money(panel.totalCents)}',
      if (monthLoaded)
        panel.overflow ? '${panel.phrase}, acima do que entrou' : panel.phrase,
      if (panel.nextDue != null)
        '${cardTitle(panel.nextDue!.card)} ${panel.nextDue!.due.label}',
      'Toque para ver a situação',
    ].join('. ');

    // Uma barra só: o quanto do que entrou já foi gasto (a barra inteira é o que entrou).
    // Uma barra "Entrou" sempre cheia não diz nada, então não existe.
    Widget spendBar() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            panel.phrase,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: panel.spentFraction,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    // Âmbar (o disco da logo) com contorno marinho: âmbar sozinho sobre papel dá 2:1.
                    color: panel.overflow ? scheme.error : AppTheme.amber,
                    border: panel.overflow
                        ? null
                        : Border.all(color: scheme.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.amber, width: 2),
      ),
      // O olhinho fica ao lado da área tocável (e não dentro dela) para o leitor de tela
      // alcançá-lo: a área tocável fala o painel inteiro e esconde os filhos.
      child: Stack(
        children: [
          Semantics(
            label: spoken,
            button: true,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Em conta',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              MoneyText(
                                panel.totalCents,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: _tabular,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 44,
                        ), // vão do olhinho, que fica por cima
                        Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    if (monthLoaded) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: panel.hasIncome
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  spendBar(),
                                  if (panel.overflow)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 18,
                                            color: scheme.error,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Gastou acima do que entrou',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(color: scheme.error),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              )
                            : Text(
                                panel.phrase,
                                style: theme.textTheme.bodyMedium,
                              ),
                      ),
                      if (!hidden && panel.hasIncome)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: Text(
                            'Entrou ${Formatters.money(panel.incomeCents)} · Gastou ${Formatters.money(panel.spentCents)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                    if (panel.nextDue != null) ...[
                      const Divider(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${cardTitle(panel.nextDue!.card)} ${panel.nextDue!.due.label}',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Positioned(top: 2, right: 34, child: BalancesEyeButton()),
        ],
      ),
    );
  }
}
