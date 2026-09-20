import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/openai_compatible_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

final _grid = SheetGrid(const {}, 0);

String _body(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

final _ok = jsonEncode({
  'despesasHeaderRow': 18,
  'despesasStartCol': 1,
  'entradaHeaderRow': -1,
  'entradaStartCol': -1,
});

OpenAiCompatibleTableLocator _locator(
  http.Client client, {
  String baseUrl = 'https://llm.exemplo.com/v1',
  String? apiKey,
  bool fallback = true,
}) => OpenAiCompatibleTableLocator(
  providerName: 'llm.exemplo.com',
  baseUrl: baseUrl,
  modelName: 'modelo-x',
  apiKey: apiKey,
  jsonObjectFallback: fallback,
  client: client,
);

void main() {
  group('chatCompletionsUrl', () {
    test('aceita o endereço base com ou sem barra e já completo', () {
      const want = 'https://llm.exemplo.com/v1/chat/completions';
      for (final base in [
        'https://llm.exemplo.com/v1',
        'https://llm.exemplo.com/v1/',
        '  https://llm.exemplo.com/v1//  ',
        'https://llm.exemplo.com/v1/chat/completions',
      ]) {
        expect(
          OpenAiCompatibleTableLocator.chatCompletionsUrl(base).toString(),
          want,
          reason: base,
        );
      }
    });
  });

  test('sem chave e sem exigi-la: chama a rede sem cabeçalho de autorização', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(_body(_ok), 200);
    });

    final result = await _locator(client).locate(_grid, sheetName: 'x');

    expect(sent.url.toString(), 'https://llm.exemplo.com/v1/chat/completions');
    expect(sent.headers.containsKey('authorization'), isFalse);
    expect((jsonDecode(sent.body) as Map)['model'], 'modelo-x');
    expect(result.despesasGerais!.headerRow, 18);
    expect(result.entradaDeValor, isNull, reason: '-1 = não encontrei');
  });

  test('com chave: manda Bearer', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(_body(_ok), 200);
    });

    await _locator(client, apiKey: '  abc  ').locate(_grid, sheetName: 'x');
    expect(sent.headers['authorization'], 'Bearer abc');
  });

  test('400 no json_schema: tenta de novo em json_object e aceita cerca de código', () async {
    final formats = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      formats.add((body['response_format'] as Map)['type'] as String);
      if (formats.length == 1) {
        return http.Response('{"error":"json_schema não suportado"}', 400);
      }
      return http.Response(_body('Aqui está:\n```json\n$_ok\n```'), 200);
    });

    final result = await _locator(client).locate(_grid, sheetName: 'x');

    expect(formats, ['json_schema', 'json_object']);
    expect(result.despesasGerais!.startCol, 1);
  });

  test('sem o modo de reserva, o 400 vira erro direto (caso da Groq)', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{"error":"bad"}', 400);
    });

    await expectLater(
      _locator(client, fallback: false).locate(_grid, sheetName: 'x'),
      throwsA(isA<LlmLocatorException>().having((e) => e.message, 'message', contains('400'))),
    );
    expect(calls, 1);
  });

  test('números em ponto flutuante inteiros (18.0) são aceitos', () async {
    final client = MockClient(
      (_) async => http.Response(
        _body(
          '{"despesasHeaderRow":18.0,"despesasStartCol":1.0,'
          '"entradaHeaderRow":-1,"entradaStartCol":-1}',
        ),
        200,
      ),
    );
    final result = await _locator(client).locate(_grid, sheetName: 'x');
    expect(result.despesasGerais!.headerRow, 18);
  });

  test('resposta fora do formato: erro que nomeia o provedor', () async {
    final client = MockClient((_) async => http.Response(_body('não sei'), 200));
    await expectLater(
      _locator(client).locate(_grid, sheetName: 'x'),
      throwsA(
        isA<LlmLocatorException>().having((e) => e.message, 'message', contains('llm.exemplo.com')),
      ),
    );
  });

  test('falha de rede vira LlmLocatorException', () async {
    final client = MockClient((_) async => throw http.ClientException('sem rota'));
    await expectLater(
      _locator(client).locate(_grid, sheetName: 'x'),
      throwsA(isA<LlmLocatorException>()),
    );
  });
}
