import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:izifnc/features/import/data/groq_table_locator.dart';
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

/// Resposta no formato da OpenAI: com `response_format` o JSON pedido vem como
/// **string** no `content`. O schema da Groq é plano, com -1 para "não achei".
String _contentBody({
  int despesasHeaderRow = 18,
  int despesasStartCol = 1,
  int entradaHeaderRow = 18,
  int entradaStartCol = 15,
}) => jsonEncode({
  'choices': [
    {
      'message': {
        'content': jsonEncode({
          'despesasHeaderRow': despesasHeaderRow,
          'despesasStartCol': despesasStartCol,
          'entradaHeaderRow': entradaHeaderRow,
          'entradaStartCol': entradaStartCol,
        }),
      },
    },
  ],
});

void main() {
  test('chave ausente lança antes de tocar na rede', () async {
    final client = MockClient((request) async {
      fail('não deveria ter chamado a rede sem chave');
    });

    expect(
      () => GroqTableLocator(client: client, apiKey: '')
          .locate(_grid, sheetName: 'Dezembro'),
      throwsA(isA<LlmLocatorException>()),
    );
  });

  test('manda o prompt com json_schema estrito e Bearer', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(_contentBody(), 200);
    });

    final locations = await GroqTableLocator(
      client: client,
      apiKey: 'chave-de-teste',
    ).locate(_grid, sheetName: 'Dezembro');

    expect(sent.headers['authorization'], 'Bearer chave-de-teste');
    final body = jsonDecode(sent.body) as Map<String, Object?>;
    final format = body['response_format'] as Map<String, Object?>;
    expect(format['type'], 'json_schema');
    expect((format['json_schema'] as Map)['strict'], isTrue);
    expect(body.containsKey('tool_choice'), isFalse);
    expect(body['messages'].toString(), contains('Dezembro'));

    expect(locations.despesasGerais!.headerRow, 18);
    expect(locations.despesasGerais!.startCol, 1);
    expect(locations.entradaDeValor!.startCol, 15);
  });

  test('-1 na resposta vira null, não erro', () async {
    final client = MockClient(
      (request) async => http.Response(
        _contentBody(entradaHeaderRow: -1, entradaStartCol: -1),
        200,
      ),
    );

    final locations = await GroqTableLocator(
      client: client,
      apiKey: 'chave-de-teste',
    ).locate(_grid, sheetName: 'Dezembro');

    expect(locations.despesasGerais, isNotNull);
    expect(locations.entradaDeValor, isNull);
  });

  test('erro HTTP vira LlmLocatorException com o corpo da resposta', () async {
    final client = MockClient(
      (request) async => http.Response('{"error":"rate_limit"}', 429),
    );

    expect(
      () => GroqTableLocator(client: client, apiKey: 'chave-de-teste')
          .locate(_grid, sheetName: 'Dezembro'),
      throwsA(
        isA<LlmLocatorException>().having(
          (e) => e.message,
          'message',
          allOf(contains('429'), contains('rate_limit')),
        ),
      ),
    );
  });

  test('content que não é o JSON pedido vira LlmLocatorException, não dado parcial', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'achei as tabelas lá pelo meio da aba'},
            },
          ],
        }),
        200,
      ),
    );

    expect(
      () => GroqTableLocator(client: client, apiKey: 'chave-de-teste')
          .locate(_grid, sheetName: 'Dezembro'),
      throwsA(isA<LlmLocatorException>()),
    );
  });
}
