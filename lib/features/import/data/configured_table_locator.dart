import 'package:http/http.dart' as http;

import 'fallback_table_locator.dart';
import 'llm_slot.dart';
import 'llm_table_locator.dart';
import 'xlsx_workbook.dart';

/// Os slots do build padrão, a partir de `--dart-define`: Groq principal e
/// Anthropic de reserva, cada um só se a chave existir. É como a versão de
/// desenvolvimento usa a API direto, sem tela de configuração.
Future<List<LlmSlot>> envSlotsResolver() async {
  const groq = String.fromEnvironment('GROQ_API_KEY');
  const anthropic = String.fromEnvironment('ANTHROPIC_API_KEY');
  return [
    if (groq.isNotEmpty) const LlmSlot(kind: LlmServiceKind.groq, apiKey: groq),
    if (anthropic.isNotEmpty) const LlmSlot(kind: LlmServiceKind.anthropic, apiKey: anthropic),
  ];
}

/// Monta, **a cada `locate`**, a cadeia de serviços a partir dos slots daquele
/// momento: o primeiro é o **principal** e os seguintes ficam de **reserva**,
/// cada um com o próprio retry. Resolver na hora da chamada (e não na criação)
/// faz configuração nova valer imediatamente, sem invalidar provider nenhum.
///
/// Slot **sem o mínimo para ser chamado** ([LlmSlot.isUsable]) é pulado — não
/// conta como falha da cadeia.
class ConfiguredTableLocator implements LlmTableLocator {
  ConfiguredTableLocator({
    this.resolveSlots = envSlotsResolver,
    this.client,
    this.retryDelay = const Duration(seconds: 2),
    this.authorize,
    this.missingKeyMessage =
        'Nenhuma chave de LLM configurada — rebuilde com '
        '--dart-define=GROQ_API_KEY=... (e, opcionalmente, ANTHROPIC_API_KEY=...).',
  });

  final SlotsResolver resolveSlots;
  final http.Client? client;
  final Duration retryDelay;
  final String missingKeyMessage;

  /// Confere, a cada chamada, se os [slots] que vão receber o texto estão
  /// autorizados (feat 0038). Fecha a janela entre o aceite na tela e uma
  /// segunda chamada depois de a pessoa trocar a configuração.
  final Future<bool> Function(List<LlmSlot> slots)? authorize;

  @override
  String get providerName => 'IA configurada';

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async {
    final slots = [
      for (final slot in await resolveSlots())
        if (slot.isUsable) slot,
    ];
    if (slots.isEmpty) throw LlmLocatorException.noKey(missingKeyMessage);
    if (authorize != null && !await authorize!(slots)) {
      throw const LlmLocatorException(
        'A configuração de IA mudou e o novo serviço ainda não foi autorizado. '
        'Tente de novo para ver a autorização.',
      );
    }
    final chain = [
      for (final slot in slots)
        RetryingTableLocator(slot.buildLocator(client: client), retryDelay: retryDelay),
    ];

    // Um serviço só dispensa o decorador de reserva (e a mensagem agregada).
    final locator = chain.length == 1 ? chain.single : FallbackTableLocator(chain);
    return locator.locate(grid, sheetName: sheetName);
  }
}
