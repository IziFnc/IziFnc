import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:izifnc/features/import/data/anthropic_table_locator.dart';
import 'package:izifnc/features/import/data/groq_table_locator.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/openai_compatible_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

/// O README promete que **valores e datas dos lançamentos nunca saem do aparelho**.
/// Este teste olha o corpo que vai de fato ao provedor, nos três localizadores.
///
/// O que sai, e o README diz: as células de **texto** da aba (cabeçalhos, nomes
/// dos lançamentos, bancos, observações). Se um dia alguém mandar célula numérica
/// ou de data, este teste falha.
SheetGrid _grid() {
  final cells = <int, Map<int, XlsxValue>>{
    1: {0: const XlsxText('Nome'), 1: const XlsxText('Valor'), 2: const XlsxText('Dia')},
    2: {0: const XlsxText('Mercado do Zé'), 1: const XlsxNumber(1234.56), 2: XlsxDate(DateTime(2026, 3, 15))},
    3: {0: const XlsxText('Farmácia'), 1: const XlsxNumber(87.9), 2: const XlsxBlank()},
  };
  return SheetGrid(cells, 3);
}

typedef _Build = LlmTableLocator Function(http.Client client);

final _builders = <String, _Build>{
  'Groq': (c) => GroqTableLocator(client: c, apiKey: 'k'),
  'Anthropic': (c) => AnthropicTableLocator(client: c, apiKey: 'k'),
  'OpenAI-compatível': (c) => OpenAiCompatibleTableLocator(
    providerName: 'llm.exemplo.com',
    baseUrl: 'https://llm.exemplo.com/v1',
    modelName: 'm',
    apiKey: 'k',
    client: c,
  ),
};

void main() {
  for (final MapEntry(key: name, value: build) in _builders.entries) {
    test('$name: o corpo enviado não leva número nem data, só texto', () async {
      String? body;
      final client = MockClient((request) async {
        body = request.body;
        return http.Response('{}', 400); // a resposta não importa aqui
      });

      await build(client).locate(_grid(), sheetName: 'Mar').then((_) {}, onError: (_) {});

      expect(body, isNotNull, reason: 'o localizador tem de ter feito a chamada');
      for (final secret in ['1234', '87.9', '87,9', '2026-03-15', '15/03', '46096']) {
        expect(body, isNot(contains(secret)), reason: 'vazou "$secret" para o provedor');
      }
      // O que o README declara que sai:
      expect(body, contains('Nome'));
      expect(body, contains('Mercado do Zé'));
    });
  }
}
