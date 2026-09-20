// Gera as planilhas **fictícias** de `docs/exemplo/` (um `.xlsx` e um
// `.esperado.json` por modelo).
//
//   dart run tool/gerar_planilhas_exemplo.dart
//
// Os bytes são determinísticos: regerar sem mudar os modelos não altera nada.
import 'dart:convert';
import 'dart:io';

import 'planilhas/layouts.dart';
import 'planilhas/xlsx_writer.dart';

void main() {
  final dir = Directory('docs/exemplo')..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');

  for (final c in allCases()) {
    File('${dir.path}/${c.slug}.xlsx').writeAsBytesSync(writeXlsx(c.sheets));
    File('${dir.path}/${c.slug}.esperado.json').writeAsStringSync('${encoder.convert(c.toJson())}\n');
    stdout.writeln('✓ ${c.slug}  (${c.sheets.length} aba(s))${c.limiteConhecido ? '  [limite conhecido]' : ''}');
  }
}
