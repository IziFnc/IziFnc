import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:izifnc/features/import/data/configured_table_locator.dart';
import 'package:izifnc/features/import/data/llm_slot.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

final _grid = SheetGrid(const {}, 0);

/// Resposta de sucesso da Groq (json_schema no content).
String _groqOk() => jsonEncode({
  'choices': [
    {
      'message': {
        'content': jsonEncode({
          'despesasHeaderRow': 18,
          'despesasStartCol': 1,
          'entradaHeaderRow': 18,
          'entradaStartCol': 15,
        }),
      },
    },
  ],
});

/// Resposta de sucesso da Anthropic (tool use).
String _anthropicOk() => jsonEncode({
  'content': [
    {
      'type': 'tool_use',
      'input': {
        'despesasGerais': {'headerRow': 18, 'startCol': 1},
        'entradaDeValor': {'headerRow': 18, 'startCol': 15},
      },
    },
  ],
});

LlmSlot _groq([String key = 'g']) => LlmSlot(kind: LlmServiceKind.groq, apiKey: key);
LlmSlot _anthropic([String key = 'a']) => LlmSlot(kind: LlmServiceKind.anthropic, apiKey: key);
const _custom = LlmSlot(
  kind: LlmServiceKind.openaiCompatible,
  baseUrl: 'https://llm.exemplo.com/v1',
  model: 'meu-modelo',
);

SlotsResolver _slots(List<LlmSlot> slots) => () async => slots;

/// Cliente que responde por host e registra quem foi chamado.
class _Router {
  _Router({this.groq, this.anthropic, this.custom});

  final http.Response Function()? groq;
  final http.Response Function()? anthropic;
  final http.Response Function()? custom;
  final calls = <String>[];
  final bodies = <String, Map<String, Object?>>{};

  http.Client get client => MockClient((request) async {
    final host = request.url.host;
    final name = host.contains('groq')
        ? 'groq'
        : host.contains('anthropic')
        ? 'anthropic'
        : 'custom';
    calls.add(name);
    bodies[name] = jsonDecode(request.body) as Map<String, Object?>;
    final answer = switch (name) {
      'groq' => groq,
      'anthropic' => anthropic,
      _ => custom,
    };
    if (answer == null) fail('$name não deveria ser chamado');
    return answer();
  });
}

void main() {
  test('sem nenhum slot: erro claro marcado como missingKey, sem tocar na rede', () async {
    final locator = ConfiguredTableLocator(
      resolveSlots: _slots([]),
      client: MockClient((_) async => fail('não deveria chamar a rede')),
    );

    await expectLater(
      locator.locate(_grid, sheetName: 'x'),
      throwsA(isA<LlmLocatorException>().having((e) => e.missingKey, 'missingKey', isTrue)),
    );
  });

  test('Groq ou Anthropic sem chave não contam: são pulados', () async {
    final locator = ConfiguredTableLocator(
      resolveSlots: _slots([_groq('  '), _anthropic('')]),
      client: MockClient((_) async => fail('não deveria chamar a rede')),
    );

    await expectLater(
      locator.locate(_grid, sheetName: 'x'),
      throwsA(isA<LlmLocatorException>().having((e) => e.missingKey, 'missingKey', isTrue)),
    );
  });

  test('só a Groq: usa a Groq e não avisa nada', () async {
    final router = _Router(groq: () => http.Response(_groqOk(), 200));
    final locator = ConfiguredTableLocator(resolveSlots: _slots([_groq()]), client: router.client);

    final result = await locator.locate(_grid, sheetName: 'x');
    expect(router.calls, ['groq']);
    expect(result.despesasGerais!.headerRow, 18);
    expect(result.fallbackNote, isNull);
  });

  test('só a Anthropic: funciona sozinha', () async {
    final router = _Router(anthropic: () => http.Response(_anthropicOk(), 200));
    final locator = ConfiguredTableLocator(
      resolveSlots: _slots([_anthropic()]),
      client: router.client,
    );

    final result = await locator.locate(_grid, sheetName: 'x');
    expect(router.calls, ['anthropic']);
    expect(result.fallbackNote, isNull);
  });

  test('a ordem da lista manda: principal primeiro, reserva só se a principal falhar', () async {
    final router = _Router(
      groq: () => http.Response(_groqOk(), 200),
      anthropic: () => http.Response(_anthropicOk(), 200),
    );
    final locator = ConfiguredTableLocator(
      resolveSlots: _slots([_anthropic(), _groq()]),
      client: router.client,
    );

    final result = await locator.locate(_grid, sheetName: 'x');
    expect(result.servedBy, 'Anthropic');
    expect(router.calls, ['anthropic'], reason: 'a reserva (Groq) nem é chamada');
  });

  test('principal com chave inválida (401): a reserva responde e a tela é avisada', () async {
    final router = _Router(
      groq: () => http.Response('{"error":"invalid_api_key"}', 401),
      anthropic: () => http.Response(_anthropicOk(), 200),
    );
    final locator = ConfiguredTableLocator(
      resolveSlots: _slots([_groq(), _anthropic()]),
      client: router.client,
    );

    final result = await locator.locate(_grid, sheetName: 'x');
    expect(result.servedBy, 'Anthropic');
    expect(result.fallbackNote, allOf(contains('Groq'), contains('401')));
    expect(router.calls, ['groq', 'anthropic'], reason: '401 é permanente: sem retry');
  });

  test('principal com 503 passageiro: o retry resolve antes da reserva', () async {
    var groqCalls = 0;
    final router = _Router(
      groq: () => ++groqCalls == 1
          ? http.Response('{"error":"overloaded"}', 503)
          : http.Response(_groqOk(), 200),
    );
    final locator = ConfiguredTableLocator(
      resolveSlots: _slots([_groq(), _anthropic()]),
      client: router.client,
      retryDelay: Duration.zero,
    );

    final result = await locator.locate(_grid, sheetName: 'x');
    expect(result.servedBy, 'Groq');
    expect(groqCalls, 2);
  });

  test('os slots são resolvidos a cada chamada (configuração nova vale na hora)', () async {
    var slots = <LlmSlot>[];
    final router = _Router(groq: () => http.Response(_groqOk(), 200));
    final locator = ConfiguredTableLocator(resolveSlots: () async => slots, client: router.client);

    await expectLater(locator.locate(_grid, sheetName: 'x'), throwsA(isA<LlmLocatorException>()));
    slots = [_groq('agora-tem')];
    final result = await locator.locate(_grid, sheetName: 'x');
    expect(result.despesasGerais, isNotNull);
  });

  test('o modelo do slot vai na requisição (Groq, Anthropic e outro)', () async {
    final router = _Router(
      groq: () => http.Response('{"error":"x"}', 401),
      anthropic: () => http.Response('{"error":"x"}', 401),
      custom: () => http.Response(_groqOk(), 200),
    );
    final locator = ConfiguredTableLocator(
      resolveSlots: _slots([
        const LlmSlot(kind: LlmServiceKind.groq, apiKey: 'g', model: 'modelo-groq'),
        const LlmSlot(kind: LlmServiceKind.anthropic, apiKey: 'a', model: 'modelo-claude'),
        _custom,
      ]),
      client: router.client,
    );

    await locator.locate(_grid, sheetName: 'x');
    expect(router.bodies['groq']!['model'], 'modelo-groq');
    expect(router.bodies['anthropic']!['model'], 'modelo-claude');
    expect(router.bodies['custom']!['model'], 'meu-modelo');
  });

  group('serviço "outro" (compatível com OpenAI)', () {
    test('vale sozinho e sem chave (servidor local, por exemplo)', () async {
      final router = _Router(custom: () => http.Response(_groqOk(), 200));
      final locator = ConfiguredTableLocator(resolveSlots: _slots([_custom]), client: router.client);

      final result = await locator.locate(_grid, sheetName: 'x');
      expect(router.calls, ['custom']);
      expect(result.despesasGerais!.headerRow, 18);
      expect(result.fallbackNote, isNull);
    });

    test('como principal, com a Groq de reserva: falhou, a reserva assume e avisa', () async {
      final router = _Router(
        custom: () => http.Response('{"error":"nope"}', 401),
        groq: () => http.Response(_groqOk(), 200),
      );
      final locator = ConfiguredTableLocator(
        resolveSlots: _slots([_custom, _groq()]),
        client: router.client,
      );

      final result = await locator.locate(_grid, sheetName: 'x');
      expect(router.calls, ['custom', 'groq']);
      expect(result.servedBy, 'Groq');
      expect(result.fallbackNote, allOf(contains('llm.exemplo.com'), contains('401')));
    });
  });

  group('envSlotsResolver', () {
    test('sem --dart-define nenhuma chave existe: lista vazia', () async {
      expect(await envSlotsResolver(), isEmpty);
    });
  });
}
