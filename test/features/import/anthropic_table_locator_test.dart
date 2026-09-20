import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:izifnc/features/import/data/anthropic_table_locator.dart';
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

final _grid = gridFrom({
  (18, 1): const XlsxText('Nome'),
  (18, 2): const XlsxText('Valor'),
  (18, 3): const XlsxText('Tipo'),
  (18, 4): const XlsxText('Banco'),
  (18, 5): const XlsxText('Observação'),
  (18, 6): const XlsxText('Dia'),
});

/// Resposta da Messages API no formato de tool use, como a de verdade chega.
String _toolUseBody({Object? despesas, Object? entrada}) => jsonEncode({
  'content': [
    {
      'type': 'tool_use',
      'name': 'locate_tables',
      'input': {'despesasGerais': despesas, 'entradaDeValor': entrada},
    },
  ],
});

void main() {
  test('chave ausente lança antes de tocar na rede', () async {
    final client = MockClient((request) async {
      fail('não deveria ter chamado a rede sem chave');
    });
    final locator = AnthropicTableLocator(client: client, apiKey: '');

    expect(
      () => locator.locate(_grid, sheetName: 'Dezembro'),
      throwsA(isA<LlmLocatorException>()),
    );
  });

  test('manda o prompt com tool use forçado e sem valores da planilha', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(
        _toolUseBody(
          despesas: {'headerRow': 18, 'startCol': 1},
          entrada: {'headerRow': 18, 'startCol': 15},
        ),
        200,
      );
    });

    final locations = await AnthropicTableLocator(
      client: client,
      apiKey: 'chave-de-teste',
    ).locate(_grid, sheetName: 'Dezembro');

    final body = jsonDecode(sent.body) as Map<String, Object?>;
    expect(sent.headers['x-api-key'], 'chave-de-teste');
    expect(body['tool_choice'], {'type': 'tool', 'name': 'locate_tables'});
    expect((body['tools'] as List).single, isA<Map>());
    expect(body['messages'].toString(), contains('Dezembro'));

    expect(locations.despesasGerais!.headerRow, 18);
    expect(locations.despesasGerais!.startCol, 1);
    expect(locations.entradaDeValor!.startCol, 15);
  });

  test('tabela ausente na resposta vira null, não erro', () async {
    final client = MockClient(
      (request) async => http.Response(
        _toolUseBody(despesas: {'headerRow': 18, 'startCol': 1}, entrada: null),
        200,
      ),
    );

    final locations = await AnthropicTableLocator(
      client: client,
      apiKey: 'chave-de-teste',
    ).locate(_grid, sheetName: 'Dezembro');

    expect(locations.despesasGerais, isNotNull);
    expect(locations.entradaDeValor, isNull);
  });

  test('erro HTTP vira LlmLocatorException com o corpo da resposta', () async {
    final client = MockClient(
      (request) async => http.Response('{"error":"overloaded"}', 529),
    );

    expect(
      () => AnthropicTableLocator(
        client: client,
        apiKey: 'chave-de-teste',
      ).locate(_grid, sheetName: 'Dezembro'),
      throwsA(
        isA<LlmLocatorException>().having(
          (e) => e.message,
          'message',
          allOf(contains('529'), contains('overloaded')),
        ),
      ),
    );
  });

  test('resposta fora do formato vira LlmLocatorException, não dado parcial', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': 'achei as tabelas lá pelo meio da aba'},
          ],
        }),
        200,
      ),
    );

    expect(
      () => AnthropicTableLocator(
        client: client,
        apiKey: 'chave-de-teste',
      ).locate(_grid, sheetName: 'Dezembro'),
      throwsA(isA<LlmLocatorException>()),
    );
  });
}
