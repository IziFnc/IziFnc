import 'package:flutter/foundation.dart';

import 'formatters.dart';

/// Um mês específico (ano + mês), sem dia.
///
/// É a unidade de "competência" do app: todo lançamento pertence a um
/// [YearMonth], que nem sempre é o mês da data dele (ver `competenceOf`).
///
/// No banco é gravado como [key] (`yyyymm`, ex. `202512`), que ordena
/// cronologicamente como inteiro e dá para indexar.
@immutable
final class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, 'mês fora de 1..12');

  factory YearMonth.of(DateTime date) => YearMonth(date.year, date.month);

  factory YearMonth.fromKey(int key) => YearMonth(key ~/ 100, key % 100);

  final int year;
  final int month;

  /// `yyyymm`, o formato gravado no banco.
  int get key => year * 100 + month;

  YearMonth next() =>
      month == 12 ? YearMonth(year + 1, 1) : YearMonth(year, month + 1);

  YearMonth previous() =>
      month == 1 ? YearMonth(year - 1, 12) : YearMonth(year, month - 1);

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  /// `dezembro de 2025` — para usar no meio de frase.
  String get label => Formatters.monthYear(DateTime(year, month));

  /// `Dezembro de 2025` — para título.
  String get title => label[0].toUpperCase() + label.substring(1);

  @override
  int compareTo(YearMonth other) => key.compareTo(other.key);

  @override
  bool operator ==(Object other) => other is YearMonth && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}
