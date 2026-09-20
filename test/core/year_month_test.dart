import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/core/utils/year_month.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  test('key é yyyymm e volta pelo fromKey', () {
    const ym = YearMonth(2025, 12);
    expect(ym.key, 202512);
    expect(YearMonth.fromKey(202512), ym);
  });

  test('next e previous atravessam a virada de ano', () {
    expect(const YearMonth(2025, 12).next(), const YearMonth(2026, 1));
    expect(const YearMonth(2026, 1).previous(), const YearMonth(2025, 12));
    expect(const YearMonth(2026, 5).next(), const YearMonth(2026, 6));
  });

  test('daysInMonth considera ano bissexto', () {
    expect(const YearMonth(2026, 2).daysInMonth, 28);
    expect(const YearMonth(2028, 2).daysInMonth, 29);
    expect(const YearMonth(2025, 11).daysInMonth, 30);
  });

  test('ordena cronologicamente', () {
    final list = [
      const YearMonth(2026, 1),
      const YearMonth(2025, 12),
      const YearMonth(2025, 2),
    ]..sort();
    expect(list, [
      const YearMonth(2025, 2),
      const YearMonth(2025, 12),
      const YearMonth(2026, 1),
    ]);
  });

  test('label em português', () {
    expect(const YearMonth(2025, 12).label, 'dezembro de 2025');
  });
}
