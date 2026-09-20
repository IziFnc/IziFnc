import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_table_locator.dart';
import 'xlsx_workbook.dart';

/// Localiza as tabelas da aba com qualquer serviço que fale a API de
/// *chat completions* da OpenAI (Groq, OpenAI, OpenRouter, Together, Ollama,
/// LM Studio, vLLM…). A Groq é só um caso particular disto.
///
/// A saída estruturada vem por **`response_format` com `json_schema` estrito**:
/// o JSON chega no `content` da mensagem, já no formato do schema.
///
/// Function calling forçado (`tool_choice`) foi tentado primeiro e descartado:
/// o `gpt-oss-120b` escrevia os argumentos certos como *texto* em vez de
/// chamar a ferramenta, e a Groq recusava com "Tool choice is required, but
/// model did not call a tool" — mesmo com os quatro valores corretos.
///
/// Serviços de terceiros nem sempre aceitam `json_schema`. Com
/// [jsonObjectFallback], um `400` faz uma segunda tentativa em modo
/// `json_object` (o schema vai escrito no prompt) e o parser tolera cercas
/// ```json ao redor da resposta.
class OpenAiCompatibleTableLocator implements PingableLocator {
  OpenAiCompatibleTableLocator({
    required this.providerName,
    required String baseUrl,
    required this.modelName,
    String? apiKey,
    this.requireKey = false,
    this.jsonObjectFallback = false,
    this.missingKeyMessage = 'Chave não configurada.',
    http.Client? client,
  }) : _endpoint = chatCompletionsUrl(baseUrl),
       _apiKey = (apiKey ?? '').trim(),
       _client = client ?? http.Client();

  @override
  final String providerName;

  /// Modelo em uso (para relatórios de avaliação).
  final String modelName;

  /// Exige chave (Groq). Serviços locais, como Ollama, dispensam.
  final bool requireKey;

  final bool jsonObjectFallback;
  final String missingKeyMessage;

  final Uri _endpoint;
  final String _apiKey;
  final http.Client _client;

  /// `https://host/v1` (com ou sem `/` no fim, ou já com `/chat/completions`)
  /// → `https://host/v1/chat/completions`.
  static Uri chatCompletionsUrl(String baseUrl) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/chat/completions')) return Uri.parse(base);
    return Uri.parse('$base/chat/completions');
  }

  /// Schema **plano**, com `-1` no lugar de null: objeto aninhado com união
  /// `["object","null"]` fez o modelo inventar nomes de campo (`row`/`col` em
  /// vez de `headerRow`/`startCol`). Quatro inteiros soltos não têm como ser
  /// preenchidos com o nome errado.
  static final Map<String, Object?> _schema = {
    'type': 'object',
    'properties': {
      'despesasHeaderRow': _intField(
        'Linha do cabeçalho de "Despesas Gerais", 1-based. -1 se não existir.',
      ),
      'despesasStartCol': _intField(
        'Coluna do "Nome" de "Despesas Gerais", 0-based (A=0). -1 se não existir.',
      ),
      'entradaHeaderRow': _intField(
        'Linha do cabeçalho de "Entrada de Valor", 1-based. -1 se não existir.',
      ),
      'entradaStartCol': _intField(
        'Coluna do "Nome" de "Entrada de Valor", 0-based (A=0). -1 se não existir.',
      ),
    },
    'required': [
      'despesasHeaderRow',
      'despesasStartCol',
      'entradaHeaderRow',
      'entradaStartCol',
    ],
    'additionalProperties': false,
  };

  static final Map<String, Object?> _strictFormat = {
    'type': 'json_schema',
    'json_schema': {'name': 'locate_tables', 'strict': true, 'schema': _schema},
  };

  static Map<String, Object?> _intField(String description) => {
    'type': 'integer',
    'description': description,
  };

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async {
    if (requireKey && _apiKey.isEmpty) {
      throw LlmLocatorException.noKey(missingKeyMessage);
    }

    // O prompt compartilhado fala em "devolva null"; aqui o schema é plano,
    // então a convenção de "não encontrei" é -1.
    final prompt =
        '${buildLocatePrompt(grid, sheetName)}\n'
        'Use -1 nos quatro campos que não se aplicarem, em vez de null.';

    var response = await _post(prompt, _strictFormat);
    if (response.statusCode == 400 && jsonObjectFallback) {
      response = await _post(
        '$prompt\n'
        'Responda SOMENTE com um objeto JSON, sem texto em volta, com '
        'exatamente estes quatro campos inteiros: despesasHeaderRow, '
        'despesasStartCol, entradaHeaderRow, entradaStartCol.',
        {'type': 'json_object'},
      );
    }

    if (response.statusCode != 200) {
      throw LlmLocatorException.http(providerName, response.statusCode, response.body);
    }
    return _parse(response.body);
  }

  @override
  Future<Duration> ping() async {
    if (requireKey && _apiKey.isEmpty) {
      throw LlmLocatorException.noKey(missingKeyMessage);
    }
    final watch = Stopwatch()..start();
    final http.Response response;
    try {
      response = await _client.post(
        _endpoint,
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

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (_apiKey.isNotEmpty) 'authorization': 'Bearer $_apiKey',
  };

  Future<http.Response> _post(String prompt, Map<String, Object?> responseFormat) async {
    try {
      return await _client.post(
        _endpoint,
        headers: _headers,
        body: jsonEncode({
          'model': modelName,
          'response_format': responseFormat,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );
    } catch (e) {
      throw LlmLocatorException('Não consegui falar com $providerName: $e');
    }
  }

  TableLocations _parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw LlmLocatorException(_malformed);
    }
    if (decoded is! Map) throw LlmLocatorException(_malformed);

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) throw LlmLocatorException(_malformed);
    final content = (choices.first as Map?)?['message']?['content'];
    if (content is! String) throw LlmLocatorException(_malformed);

    // O content é o JSON pedido — às vezes dentro de uma cerca ```json.
    final Object? result;
    try {
      result = jsonDecode(_stripFences(content));
    } catch (_) {
      throw LlmLocatorException(_malformed);
    }
    if (result is! Map) throw LlmLocatorException(_malformed);

    return TableLocations(
      despesasGerais: _location(result['despesasHeaderRow'], result['despesasStartCol']),
      entradaDeValor: _location(result['entradaHeaderRow'], result['entradaStartCol']),
    );
  }

  String get _malformed => '$providerName respondeu fora do formato esperado.';

  /// Fica com o trecho entre a primeira `{` e a última `}`.
  static String _stripFences(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return content;
    return content.substring(start, end + 1);
  }

  /// `-1` (ou qualquer valor negativo) é a convenção de "não encontrei" deste
  /// schema plano — vira `null`, como nos outros provedores.
  TableLocation? _location(Object? headerRow, Object? startCol) {
    final row = _asInt(headerRow);
    final col = _asInt(startCol);
    if (row == null || col == null) throw LlmLocatorException(_malformed);
    if (row < 0 || col < 0) return null;
    return TableLocation(headerRow: row, startCol: col);
  }

  /// Aceita `18` e `18.0` (alguns modelos devolvem número em ponto flutuante).
  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is double && v == v.roundToDouble()) return v.toInt();
    return null;
  }
}
