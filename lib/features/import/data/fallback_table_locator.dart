import 'llm_table_locator.dart';
import 'xlsx_workbook.dart';

/// Repete a chamada quando o erro é **passageiro** (429/503/529, marcado em
/// [LlmLocatorException.retryable]).
///
/// Medido por curl, o mesmo modelo do Gemini falhou 1 de 6 e respondeu 200 nas
/// demais: sobrecarga momentânea não deve virar mensagem de erro na primeira
/// vez. Erro permanente (chave errada, modelo inexistente, resposta
/// malformada) falha de primeira — repetir só atrasaria o erro de verdade.
///
/// O atraso dobra a cada tentativa (2s, 4s, ...). O retry fica **por
/// provedor**, antes da reserva: um 503 passageiro da Groq não deve gastar a
/// chave paga da Anthropic.
class RetryingTableLocator implements LlmTableLocator {
  RetryingTableLocator(
    this._inner, {
    this.maxAttempts = 3,
    this.retryDelay = const Duration(seconds: 2),
  });

  final LlmTableLocator _inner;
  final int maxAttempts;
  final Duration retryDelay;

  @override
  String get providerName => _inner.providerName;

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _inner.locate(grid, sheetName: sheetName);
      } on LlmLocatorException catch (e) {
        if (!e.retryable || attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(retryDelay * (1 << (attempt - 1)));
      }
    }
  }
}

/// Tenta os provedores **em ordem**; o primeiro que responde vence.
///
/// Qualquer falha passa para o próximo (inclusive chave inválida). Quando a
/// resposta vem de um provedor que não era o primeiro, [TableLocations.fallbackNote]
/// diz o que aconteceu — a reserva costuma ser paga, então isso não pode
/// acontecer em silêncio. Se todos falham, a mensagem junta os erros de cada um.
class FallbackTableLocator implements LlmTableLocator {
  FallbackTableLocator(this._locators)
    : assert(_locators.isNotEmpty, 'precisa de pelo menos um provedor');

  final List<LlmTableLocator> _locators;

  @override
  String get providerName => _locators.map((l) => l.providerName).join(' → ');

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async {
    final failures = <String>[];
    for (final locator in _locators) {
      try {
        final result = await locator.locate(grid, sheetName: sheetName);
        final note = failures.isEmpty
            ? null
            : '${locator.providerName} respondeu no lugar de '
                  '${failures.length == 1 ? 'um provedor que falhou' : 'provedores que falharam'} '
                  '(${failures.join(' | ')}).';
        return result.withServedBy(locator.providerName, fallbackNote: note);
      } on LlmLocatorException catch (e) {
        failures.add('${locator.providerName}: ${_short(e.message)}');
      }
    }
    throw LlmLocatorException(
      'Nenhum provedor conseguiu localizar as tabelas — ${failures.join(' · ')}',
    );
  }

  /// Corpo de erro de API pode ter centenas de caracteres; na nota basta o começo.
  static String _short(String message) {
    final oneLine = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length <= 140 ? oneLine : '${oneLine.substring(0, 140)}…';
  }
}
