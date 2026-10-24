import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:izifnc/features/import/data/anthropic_table_locator.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/openai_compatible_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

/// Uma conexão pendurada não pode deixar a importação (ou o "Testar") girando
/// para sempre: toda chamada ao provedor tem teto de espera.
///
/// O cliente falso nunca responde; os tetos são encurtados para o teste não esperar
/// os 60 s / 20 s de verdade.
const _short = Duration(milliseconds: 50);

http.Client _hangingClient() => MockClient((_) => Completer<http.Response>().future);

final _grid = SheetGrid(const {}, 0);

typedef _Build = PingableLocator Function(http.Client client);

final _builders = <String, _Build>{
  'Anthropic': (c) => AnthropicTableLocator(client: c, apiKey: 'k', locateTimeout: _short, pingTimeout: _short),
  'OpenAI-compatível': (c) => OpenAiCompatibleTableLocator(
    providerName: 'llm.exemplo.com',
    baseUrl: 'https://llm.exemplo.com/v1',
    modelName: 'm',
    apiKey: 'k',
    client: c,
    locateTimeout: _short,
    pingTimeout: _short,
  ),
};

void main() {
  test('os tetos de verdade são 60 s (localizar) e 20 s (testar)', () {
    expect(defaultLocateTimeout, const Duration(seconds: 60));
    expect(defaultPingTimeout, const Duration(seconds: 20));
  });

  for (final MapEntry(key: name, value: build) in _builders.entries) {
    group('timeout — $name', () {
      test('localizar: dá erro em português e não é repetido', () async {
        final locator = build(_hangingClient());
        await expectLater(
          locator.locate(_grid, sheetName: 'Set'),
          throwsA(
            isA<LlmLocatorException>()
                .having((e) => e.message, 'mensagem', contains('demorou demais'))
                .having((e) => e.retryable, 'retryable', isFalse),
          ),
        );
      });

      test('testar: dá erro de conexão em vez de ficar girando', () async {
        final locator = build(_hangingClient());
        await expectLater(
          locator.ping(),
          throwsA(isA<LlmLocatorException>().having((e) => e.message, 'mensagem', contains('Sem conexão'))),
        );
      });
    });
  }
}
