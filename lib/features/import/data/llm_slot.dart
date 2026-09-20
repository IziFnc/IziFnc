import 'package:http/http.dart' as http;

import 'anthropic_table_locator.dart';
import 'groq_table_locator.dart';
import 'llm_table_locator.dart';
import 'openai_compatible_table_locator.dart';

/// Qual serviço de IA ocupa um slot (Principal ou Reserva).
enum LlmServiceKind {
  groq('Groq'),
  anthropic('Anthropic'),

  /// Qualquer serviço que fale a API de *chat completions* da OpenAI.
  openaiCompatible('Outro (compatível com OpenAI)');

  const LlmServiceKind(this.label);
  final String label;
}

/// Um serviço de IA configurado: qual é, com que chave e, se o usuário quis
/// trocar, com qual modelo. A tela do usuário monta dois (Principal e Reserva);
/// o build padrão monta os dele a partir de `--dart-define`.
class LlmSlot {
  const LlmSlot({required this.kind, this.apiKey, this.model, this.baseUrl});

  final LlmServiceKind kind;

  /// Groq e Anthropic exigem chave; "outro" pode dispensar (servidor local).
  final String? apiKey;

  /// Vazio = o modelo padrão do serviço. No "outro" é obrigatório.
  final String? model;

  /// Só no "outro": endereço base, como `https://api.openai.com/v1`.
  final String? baseUrl;

  static bool _filled(String? s) => s != null && s.trim().isNotEmpty;

  /// Tem o mínimo para ser chamado? Groq e Anthropic precisam de chave; "outro"
  /// precisa de endereço e modelo. Quem não tem é **pulado**, não é falha.
  bool get isUsable => switch (kind) {
    LlmServiceKind.groq || LlmServiceKind.anthropic => _filled(apiKey),
    LlmServiceKind.openaiCompatible => _filled(baseUrl) && _filled(model),
  };

  /// Nome para a tela e para as mensagens: o do serviço, ou o host no "outro".
  String get displayName {
    if (kind != LlmServiceKind.openaiCompatible) return kind.label;
    final host = Uri.tryParse(baseUrl?.trim() ?? '')?.host ?? '';
    return host.isEmpty ? 'modelo próprio' : host;
  }

  /// O localizador deste slot, já com chave e modelo. Ele também sabe se testar.
  PingableLocator buildLocator({http.Client? client}) => switch (kind) {
    LlmServiceKind.groq => GroqTableLocator(client: client, apiKey: apiKey?.trim(), model: model),
    LlmServiceKind.anthropic => AnthropicTableLocator(
      client: client,
      apiKey: apiKey?.trim(),
      model: model,
    ),
    LlmServiceKind.openaiCompatible => OpenAiCompatibleTableLocator(
      providerName: displayName,
      baseUrl: baseUrl!,
      modelName: model!.trim(),
      apiKey: apiKey,
      // Serviços de terceiros nem sempre aceitam json_schema estrito.
      jsonObjectFallback: true,
      client: client,
    ),
  };
}

/// De onde vêm os slots, na ordem de preferência: `[principal, reserva?]`.
/// Lido a cada chamada, para configuração nova valer na hora.
typedef SlotsResolver = Future<List<LlmSlot>> Function();
