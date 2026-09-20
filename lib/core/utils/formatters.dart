import 'package:intl/intl.dart';

/// Formatação de moeda e datas no padrão pt-BR.
///
/// **Convenção do projeto:** valores monetários circulam pelo app como `int` em
/// **centavos**, nunca `double`. Ponto flutuante acumula erro de arredondamento e,
/// num app de finanças, isso aparece como saldo que não fecha no fim do mês.
/// A conversão para decimal acontece só aqui, na hora de exibir.
abstract final class Formatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
  );
  static final DateFormat _shortDate = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dayMonth = DateFormat('dd/MM', 'pt_BR');
  static final DateFormat _monthYear = DateFormat("MMMM 'de' y", 'pt_BR');

  /// `123456` → `R$ 1.234,56`
  static String money(int cents) => _currency.format(cents / 100);

  /// `dd/MM/yyyy`
  static String date(DateTime date) => _shortDate.format(date);

  /// `dd/MM` — para listas, onde o ano está no cabeçalho.
  static String dayMonth(DateTime date) => _dayMonth.format(date);

  /// `setembro de 2026`
  static String monthYear(DateTime date) => _monthYear.format(date);
}
