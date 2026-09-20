import '../../../core/database/app_database.dart';
import 'month_summary.dart';

/// O que a home mostra de relance (feat 0022): quanto há nas contas, quanto se
/// deve nos cartões e o que entrou e saiu no mês. Só junta números que já
/// existem (saldos e [MonthSummary]); não inventa regra nova.
class MonthSituation {
  const MonthSituation._({
    required this.accountBalances,
    required this.totalCents,
    required this.openCards,
    required this.openCardsCents,
    required this.summary,
  });

  /// [balances] é o mapa de `EntriesRepository.watchBalances`: conta corrente com
  /// o saldo, cartão com o saldo **negativo** quando há fatura (em aberto = -saldo).
  /// [summary] é o do mês exibido, ou nulo se o mês não tem lançamentos.
  factory MonthSituation.from({
    required List<Account> accounts,
    required Map<int, int> balances,
    MonthSummary? summary,
  }) {
    final checking = [
      for (final a in accounts)
        if (!a.kind.isCard) (account: a, cents: balances[a.id] ?? 0),
    ];
    final openCards = [
      for (final a in accounts)
        if (a.kind.isCard && (balances[a.id] ?? 0) != 0) (card: a, openCents: -(balances[a.id] ?? 0)),
    ];
    return MonthSituation._(
      accountBalances: checking,
      totalCents: checking.fold(0, (sum, b) => sum + b.cents),
      openCards: openCards,
      // Cartão com crédito (saldo positivo) não abate a fatura de outro cartão.
      openCardsCents: openCards.fold(0, (sum, c) => c.openCents > 0 ? sum + c.openCents : sum),
      summary: summary,
    );
  }

  /// Contas correntes, na ordem recebida, com o saldo de hoje.
  final List<({Account account, int cents})> accountBalances;

  /// "Em conta": a soma dos saldos das contas correntes.
  final int totalCents;

  /// Cartões com algo em aberto (ou com crédito), com o valor em aberto.
  final List<({Account card, int openCents})> openCards;

  /// "Faturas abertas": a soma do que se deve nos cartões.
  final int openCardsCents;

  final MonthSummary? summary;

  /// "Entrou" no mês.
  int get incomeCents => summary?.incomeCents ?? 0;

  /// "Gastou" no mês: o que saiu no débito mais o que foi para os cartões.
  int get spentCents =>
      (summary?.debitExpenseCents ?? 0) + (summary?.cards.fold<int>(0, (s, c) => s + c.cents) ?? 0);
}
