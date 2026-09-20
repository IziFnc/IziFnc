import 'xlsx_workbook.dart';

/// Uma linha bruta de uma das tabelas de lançamento da planilha, já separada
/// por coluna (mas ainda sem interpretar nome de banco, tipo etc. — isso é
/// trabalho do domínio, em `parsed_row.dart`).
class RawTableRow {
  const RawTableRow(this.sheetRow, this.values);

  /// A linha da planilha (1-based), para mensagens de erro apontarem o lugar.
  final int sheetRow;

  /// Valores da linha, na ordem das colunas do cabeçalho.
  final List<XlsxValue> values;

  XlsxValue operator [](int index) => index < values.length ? values[index] : const XlsxBlank();
}

/// As duas tabelas desta entrega, já localizadas e com as linhas extraídas.
class SpreadsheetTables {
  const SpreadsheetTables({required this.despesasGerais, required this.entradaDeValor});

  /// Colunas: Nome, Valor, Tipo, Banco, Observação, Dia.
  final List<RawTableRow> despesasGerais;

  /// Colunas: Nome, Valor, Banco, Observação, Dia.
  final List<RawTableRow> entradaDeValor;
}

/// Nomes das colunas de cada tabela, na ordem — usado só para saber **quantas**
/// colunas ler a partir do início de cada tabela (`readTableRows`). Onde a
/// tabela começa é responsabilidade de quem localiza (`LlmTableLocator`).
const despesasGeraisHeader = ['Nome', 'Valor', 'Tipo', 'Banco', 'Observação', 'Dia'];
const entradaDeValorHeader = ['Nome', 'Valor', 'Banco', 'Observação', 'Dia'];

/// Lê as linhas de uma tabela a partir do cabeçalho já localizado, parando
/// depois de 3 linhas em branco seguidas (fim da tabela).
List<RawTableRow> readTableRows(SheetGrid grid, int headerRow, int startCol, int columnCount) {
  final rows = <RawTableRow>[];
  var blankStreak = 0;
  for (var r = headerRow + 1; r <= grid.maxRow && blankStreak < 3; r++) {
    final values = [for (var c = 0; c < columnCount; c++) grid.cell(r, startCol + c)];
    if (values.every((v) => v is XlsxBlank)) {
      blankStreak++;
      continue;
    }
    blankStreak = 0;
    rows.add(RawTableRow(r, values));
  }
  return rows;
}
