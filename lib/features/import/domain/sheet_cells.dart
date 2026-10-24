import '../data/xlsx_workbook.dart';
import 'parsed_row.dart';

// Leitura tolerante das células da planilha (texto, valor, data, tipo).

String? cellText(XlsxValue value) => switch (value) {
  XlsxText(:final value) when value.trim().isNotEmpty => value.trim(),
  _ => null,
};

/// Aceita número (o caso normal) ou texto numérico ("50,00") — algumas
/// células da planilha podem ter sido digitadas como texto.
int? cellCents(XlsxValue value) {
  final number = switch (value) {
    XlsxNumber(:final value) => value,
    XlsxText(:final value) => double.tryParse(value.trim().replaceAll(',', '.')),
    _ => null,
  };
  return number == null ? null : (number.abs() * 100).round();
}

/// Aceita célula-data (o caso normal) ou número puro — se o estilo da célula
/// não foi reconhecido como data mas a coluna só pode ser uma data (Dia),
/// ainda dá para converter pelo valor serial.
DateTime? cellDate(XlsxValue value) => switch (value) {
  XlsxDate(:final value) => value,
  XlsxNumber(:final value) => excelSerialToDate(value),
  _ => null,
};

SourceTipo? parseTipo(String normalized) => switch (normalized) {
  'debito' => SourceTipo.debito,
  'credito' => SourceTipo.credito,
  _ => null,
};
