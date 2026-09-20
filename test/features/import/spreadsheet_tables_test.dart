import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/import/data/spreadsheet_tables.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

/// Monta uma grade à mão, sem passar por XML nem zip — testa só a leitura de
/// linhas a partir de um cabeçalho já localizado.
SheetGrid gridFrom(Map<(int row, int col), XlsxValue> cells) {
  final byRow = <int, Map<int, XlsxValue>>{};
  var maxRow = 0;
  for (final entry in cells.entries) {
    final (row, col) = entry.key;
    maxRow = row > maxRow ? row : maxRow;
    (byRow[row] ??= {})[col] = entry.value;
  }
  return SheetGrid(byRow, maxRow);
}

void main() {
  test('lê as linhas de uma tabela a partir do cabeçalho já localizado', () {
    final cells = <(int, int), XlsxValue>{
      (1, 1): const XlsxText('Nome'),
      (1, 2): const XlsxText('Valor'),
      (1, 3): const XlsxText('Tipo'),
      (1, 4): const XlsxText('Banco'),
      (1, 5): const XlsxText('Observação'),
      (1, 6): const XlsxText('Dia'),
      (2, 1): const XlsxText('Mercado'),
      (2, 2): const XlsxNumber(50),
      (2, 3): const XlsxText('Debito'),
      (2, 4): const XlsxText('Bradesco'),
      (2, 6): XlsxDate(DateTime(2025, 12, 19)),
    };

    final rows = readTableRows(gridFrom(cells), 1, 1, despesasGeraisHeader.length);
    expect(rows, hasLength(1));
    expect((rows.single[0] as XlsxText).value, 'Mercado');
    expect(rows.single.values, hasLength(6));
  });

  test('para de ler depois de 3 linhas em branco seguidas', () {
    final cells = <(int, int), XlsxValue>{
      (1, 10): const XlsxText('Nome'),
      (1, 11): const XlsxText('Valor'),
      (1, 12): const XlsxText('Banco'),
      (1, 13): const XlsxText('Observação'),
      (1, 14): const XlsxText('Dia'),
      (2, 10): const XlsxText('Salário'),
      (2, 11): const XlsxNumber(1000),
      // linhas 3, 4, 5 em branco
      (6, 10): const XlsxText('Não deveria entrar'),
    };

    final rows = readTableRows(gridFrom(cells), 1, 10, entradaDeValorHeader.length);
    expect(rows, hasLength(1));
    expect((rows.single[0] as XlsxText).value, 'Salário');
  });
}
