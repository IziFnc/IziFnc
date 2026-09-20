import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:izifnc/features/import/data/anthropic_table_locator.dart';
import 'package:izifnc/features/import/data/groq_table_locator.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/openai_compatible_table_locator.dart';

/// Os três localizadores respondem ao "Testar" do mesmo jeito: uma requisição
/// mínima, sem dado de planilha, que diz se chave, endereço e modelo estão certos.
typedef _Build = PingableLocator Function(http.Client client, {String key});

final _builders = <String, _Build>{
  'Groq': (client, {key = 'k'}) => GroqTableLocator(client: client, apiKey: key),
  'Anthropic': (client, {key = 'k'}) => AnthropicTableLocator(client: client, apiKey: key),
  'OpenAI-compatível': (client, {key = 'k'}) => OpenAiCompatibleTableLocator(
    providerName: 'llm.exemplo.com',
    baseUrl: 'https://llm.exemplo.com/v1',
    modelName: 'm',
    apiKey: key,
    client: client,
  ),
};

/// Corpo de sucesso qualquer: o teste só olha o status.
final _ok = jsonEncode({'ok': true});

void main() {
  for (final MapEntry(key: name, value: build) in _builders.entries) {
    group('ping — $name', () {
      test('200: devolve quanto demorou e faz UMA chamada, sem retry', () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response(_ok, 200);
        });

        final took = await build(client).ping();

        expect(took, isA<Duration>());
        expect(calls, 1);
      });

      test('a requisição é mínima e não leva dado da planilha', () async {
        late Map<String, Object?> body;
        final client = MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(_ok, 200);
        });

        await build(client).ping();

        final text = jsonEncode(body['messages']);
        expect(text.length, lessThan(120), reason: 'só uma frase curta');
        expect(text, isNot(contains('planilha')));
        expect(
          (body['max_tokens'] as int?) ?? (body['max_completion_tokens'] as int?),
          lessThanOrEqualTo(64),
          reason: 'gasta poucos tokens',
        );
      });

      test('401 e 403: diz que a chave foi recusada', () async {
        for (final status in [401, 403]) {
          final client = MockClient((_) async => http.Response('{"error":"x"}', status));
          await expectLater(
            build(client).ping(),
            throwsA(
              isA<LlmLocatorException>().having((e) => e.message, 'message', contains('chave')),
            ),
            reason: '$status',
          );
        }
      });

      test('404: aponta modelo ou endereço', () async {
        final client = MockClient((_) async => http.Response('{"error":"x"}', 404));
        await expectLater(
          build(client).ping(),
          throwsA(
            isA<LlmLocatorException>().having(
              (e) => e.message,
              'message',
              allOf(contains('modelo'), contains('endereço')),
            ),
          ),
        );
      });

      test('429: limite de uso (a chave, em si, está certa)', () async {
        final client = MockClient((_) async => http.Response('{"error":"x"}', 429));
        await expectLater(
          build(client).ping(),
          throwsA(
            isA<LlmLocatorException>().having((e) => e.message, 'message', contains('limite')),
          ),
        );
      });

      test('5xx: serviço fora do ar', () async {
        final client = MockClient((_) async => http.Response('{"error":"x"}', 503));
        await expectLater(
          build(client).ping(),
          throwsA(
            isA<LlmLocatorException>().having((e) => e.message, 'message', contains('fora do ar')),
          ),
        );
      });

      test('sem rede: fala em conexão', () async {
        final client = MockClient((_) async => throw http.ClientException('sem rota'));
        await expectLater(
          build(client).ping(),
          throwsA(
            isA<LlmLocatorException>().having((e) => e.message, 'message', contains('conexão')),
          ),
        );
      });
    });
  }

  test('Groq e Anthropic sem chave: falham antes de tocar na rede', () async {
    final client = MockClient((_) async => fail('não deveria chamar a rede'));
    for (final name in ['Groq', 'Anthropic']) {
      await expectLater(
        _builders[name]!(client, key: '  ').ping(),
        throwsA(isA<LlmLocatorException>().having((e) => e.missingKey, 'missingKey', isTrue)),
        reason: name,
      );
    }
  });

  test('serviço "outro" aceita ping sem chave (servidor local)', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(_ok, 200);
    });

    await _builders['OpenAI-compatível']!(client, key: '').ping();
    expect(sent.headers.containsKey('authorization'), isFalse);
  });
}
