/// Quando vence o cartão, em palavras para a tela "Situação" (feat 0042).
///
/// O app não conhece a fatura de cada ciclo (o "em aberto" é o saldo do cartão),
/// então só diz **o próximo vencimento** a partir do dia cadastrado. Nunca afirma
/// que uma fatura "venceu".
class DueInfo {
  const DueInfo._(this.daysUntil, this.label);

  /// Dias até o próximo vencimento (0 = hoje); nulo quando o cartão não tem dia
  /// de vencimento cadastrado.
  final int? daysUntil;

  /// "vence hoje", "vence amanhã", "vence em 3 dias" ou "sem vencimento cadastrado".
  final String label;

  /// Próximo vencimento a partir de [today] (só a data conta, a hora não).
  factory DueInfo.of({required int? dueDay, required DateTime today}) {
    if (dueDay == null) return const DueInfo._(null, 'sem vencimento cadastrado');
    final day = DateTime(today.year, today.month, today.day);
    var due = _clamp(day.year, day.month, dueDay);
    if (due.isBefore(day)) {
      final next = DateTime(day.year, day.month + 1);
      due = _clamp(next.year, next.month, dueDay);
    }
    final days = due.difference(day).inDays;
    final label = switch (days) {
      0 => 'vence hoje',
      1 => 'vence amanhã',
      _ => 'vence em $days dias',
    };
    return DueInfo._(days, label);
  }

  /// O dia [dueDay] no mês, limitado ao último dia dele (dia 31 em fevereiro vira 28 ou 29).
  static DateTime _clamp(int year, int month, int dueDay) {
    final last = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dueDay > last ? last : dueDay);
  }
}
