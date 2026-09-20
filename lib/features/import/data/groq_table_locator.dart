import 'openai_compatible_table_locator.dart';

/// Localiza as tabelas da aba com a Groq, que hospeda modelos abertos numa API
/// compatível com a da OpenAI — ver [OpenAiCompatibleTableLocator] para o
/// formato da conversa.
class GroqTableLocator extends OpenAiCompatibleTableLocator {
  GroqTableLocator({super.client, String? apiKey, String? model})
    : super(
        providerName: 'Groq',
        baseUrl: 'https://api.groq.com/openai/v1',
        modelName: (model == null || model.trim().isEmpty) ? _model : model.trim(),
        apiKey: apiKey ?? const String.fromEnvironment('GROQ_API_KEY'),
        requireKey: true,
        missingKeyMessage:
            'Chave da Groq não configurada — rebuilde com '
            '--dart-define=GROQ_API_KEY=...',
      );

  /// Modelos de provedores são aposentados com frequência (três em um dia
  /// durante a comparação); `--dart-define=GROQ_MODEL=...` troca sem editar código.
  static const _model = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'openai/gpt-oss-120b',
  );
}
