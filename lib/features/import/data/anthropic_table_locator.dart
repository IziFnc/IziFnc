import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_table_locator.dart';
import 'xlsx_workbook.dart';

/// Localiza as tabelas da aba com a Messages API da Anthropic.
///
/// A saída estruturada vem por **tool use forçado**: declara-se uma tool
/// `locate_tables` com o JSON Schema do resultado e `tool_choice` obrigando o
/// modelo a chamá-la — assim a resposta já chega no formato certo, sem parsear
/// texto livre.
class AnthropicTableLocator implements PingableLocator {
  AnthropicTableLocator({http.Client? client, String? apiKey, String? model})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? const String.fromEnvironment('ANTHROPIC_API_KEY'),
      modelName = (model == null || model.trim().isEmpty) ? _defaultModel : model.trim();

  final http.Client _client;
  final String _apiKey;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  /// `--dart-define=ANTHROPIC_MODEL=...` troca o modelo sem editar código.
  static const _defaultModel = String.fromEnvironment(
    'ANTHROPIC_MODEL',
    defaultValue: 'claude-sonnet-5',
  );

  @override
  String get providerName => 'Anthropic';

  /// Modelo em uso (relatórios de avaliação e o teste da tela).
  final String modelName;
  static const _apiVersion = '2023-06-01';

  static const _missingKeyMessage =
      'Chave da Anthropic não configurada — rebuilde com '
      '--dart-define=ANTHROPIC_API_KEY=...';

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'x-api-key': _apiKey,
    'anthropic-version': _apiVersion,
  };

  @override
  Future<Duration> ping() async {
    if (_apiKey.trim().isEmpty) throw LlmLocatorException.noKey(_missingKeyMessage);
    final watch = Stopwatch()..start();
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'model': modelName,
          'max_tokens': pingMaxTokens,
          'messages': [
            {'role': 'user', 'content': pingPrompt},
          ],
        }),
      );
    } catch (_) {
      throw LlmLocatorException(pingConnectionMessage(providerName));
    }
    watch.stop();
    if (response.statusCode != 200) {
      throw LlmLocatorException(pingFailureMessage(providerName, response.statusCode));
    }
    return watch.elapsed;
  }

  static final _toolSchema = {
    'name': 'locate_tables',
    'description': 'Informa onde cada tabela de lançamentos começa na aba.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'despesasGerais': _locationSchema('Tabela "Despesas Gerais", ou null.'),
        'entradaDeValor': _locationSchema('Tabela "Entrada de Valor", ou null.'),
      },
      'required': ['despesasGerais', 'entradaDeValor'],
    },
  };

  static Map<String, Object?> _locationSchema(String description) => {
    'type': ['object', 'null'],
    'description': description,
    'properties': {
      'headerRow': {'type': 'integer', 'description': 'Linha do cabeçalho, 1-based.'},
      'startCol': {'type': 'integer', 'description': 'Coluna do "Nome", 0-based (A=0).'},
    },
    'required': ['headerRow', 'startCol'],
  };

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async {
    if (_apiKey.isEmpty) throw LlmLocatorException.noKey(_missingKeyMessage);

    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'model': modelName,
          'max_tokens': 1024,
          'tools': [_toolSchema],
          'tool_choice': {'type': 'tool', 'name': 'locate_tables'},
          'messages': [
            {'role': 'user', 'content': buildLocatePrompt(grid, sheetName)},
          ],
        }),
      );
    } catch (e) {
      throw LlmLocatorException('Não consegui falar com a Anthropic: $e');
    }

    if (response.statusCode != 200) {
      throw LlmLocatorException.http('Anthropic', response.statusCode, response.body);
    }

    return _parse(response.body);
  }

  TableLocations _parse(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map) throw const LlmLocatorException(_malformed);

    final content = decoded['content'];
    if (content is! List) throw const LlmLocatorException(_malformed);

    for (final block in content) {
      if (block is Map && block['type'] == 'tool_use') {
        final input = block['input'];
        if (input is! Map) throw const LlmLocatorException(_malformed);
        return TableLocations(
          despesasGerais: _location(input['despesasGerais']),
          entradaDeValor: _location(input['entradaDeValor']),
        );
      }
    }
    throw const LlmLocatorException(_malformed);
  }

  static const _malformed = 'A Anthropic respondeu fora do formato esperado.';

  static TableLocation? _location(Object? value) {
    if (value == null) return null;
    if (value is! Map) throw const LlmLocatorException(_malformed);
    final headerRow = value['headerRow'];
    final startCol = value['startCol'];
    if (headerRow is! int || startCol is! int) {
      throw const LlmLocatorException(_malformed);
    }
    return TableLocation(headerRow: headerRow, startCol: startCol);
  }
}
