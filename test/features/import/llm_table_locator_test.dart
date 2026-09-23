import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

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

class _FakeLocator implements LlmTableLocator {
  _FakeLocator(this.result, {this.then});
  final TableLocations result;

  /// A resposta das chamadas seguintes (a IA às vezes acerta na segunda).
  final TableLocations? then;
  int calls = 0;

  @override
  String get providerName => 'Fake';

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async =>
      calls++ == 0 ? result : (then ?? result);
}

void main() {
  group('describeTextCells', () {
    test('lista só as células de texto, nunca número ou data', () {
      final grid = gridFrom({
        (1, 1): const XlsxText('Nome'),
        (1, 2): const XlsxText('Valor'),
        (2, 1): const XlsxText('Mercado'),
        (2, 2): const XlsxNumber(50), // não deve aparecer
        (2, 3): XlsxDate(DateTime(2025, 12, 19)), // não deve aparecer
      });

      final description = describeTextCells(grid);
      expect(description, contains('B1="Nome"'));
      expect(description, contains('B2="Mercado"'));
      expect(description, isNot(contains('50')));
      expect(description, isNot(contains('2025')));
    });
  });

  group('extractTablesWithAi', () {
    final grid = gridFrom({
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
      (10, 1): const XlsxText('Nome'),
      (10, 2): const XlsxText('Valor'),
      (10, 3): const XlsxText('Banco'),
      (10, 4): const XlsxText('Observação'),
      (10, 5): const XlsxText('Dia'),
      (11, 1): const XlsxText('Salário'),
      (11, 2): const XlsxNumber(5000),
    });

    test('extrai as duas tabelas quando o locator acha as duas', () async {
      final locator = _FakeLocator(
        const TableLocations(
          despesasGerais: TableLocation(headerRow: 1, startCol: 1),
          entradaDeValor: TableLocation(headerRow: 10, startCol: 1),
        ),
      );

      final result = await extractTablesWithAi(grid, sheetName: 'Aba1', locator: locator);
      expect(result.tables.despesasGerais, hasLength(1));
      expect((result.tables.despesasGerais.single[0] as XlsxText).value, 'Mercado');
      expect(result.tables.entradaDeValor, hasLength(1));
      expect((result.tables.entradaDeValor.single[0] as XlsxText).value, 'Salário');
      expect(result.note, isNull);
    });

    test('repassa o aviso de reserva quando o provedor principal falhou', () async {
      final locator = _FakeLocator(
        const TableLocations(
          despesasGerais: TableLocation(headerRow: 1, startCol: 1),
          entradaDeValor: TableLocation(headerRow: 10, startCol: 1),
          fallbackNote: 'Anthropic respondeu no lugar da Groq',
        ),
      );

      final result = await extractTablesWithAi(grid, sheetName: 'Aba1', locator: locator);
      expect(result.note, 'Anthropic respondeu no lugar da Groq');
    });

    test('falta uma tabela nas duas tentativas: TablesNotFoundException (não "arquivo inválido")', () async {
      final locator = _FakeLocator(
        const TableLocations(despesasGerais: TableLocation(headerRow: 1, startCol: 1)),
      );

      await expectLater(
        extractTablesWithAi(grid, sheetName: 'Aba1', locator: locator),
        throwsA(isA<TablesNotFoundException>()),
      );
      expect(locator.calls, 2, reason: 'tenta de novo uma vez antes de desistir');
    });

    test('a IA erra na primeira e acha na segunda: segue normal (visto na planilha real)', () async {
      final locator = _FakeLocator(
        const TableLocations(despesasGerais: TableLocation(headerRow: 1, startCol: 1)),
        then: const TableLocations(
          despesasGerais: TableLocation(headerRow: 1, startCol: 1),
          entradaDeValor: TableLocation(headerRow: 10, startCol: 1),
        ),
      );

      final result = await extractTablesWithAi(grid, sheetName: 'Aba1', locator: locator);
      expect(result.tables.entradaDeValor, hasLength(1));
      expect(locator.calls, 2);
    });
  });

  group('LlmLocatorException', () {
    test('http: só 429/503/529 são passageiros', () {
      bool retryable(int s) => LlmLocatorException.http('X', s, '').retryable;
      expect([429, 503, 529].every(retryable), isTrue);
      expect([400, 401, 403, 404, 500].any(retryable), isFalse);
    });

    test('noKey marca missingKey e não é passageira', () {
      final e = LlmLocatorException.noKey('sem chave');
      expect(e.missingKey, isTrue);
      expect(e.retryable, isFalse);
    });
  });
}
