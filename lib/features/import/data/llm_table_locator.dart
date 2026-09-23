import 'spreadsheet_tables.dart';
import 'xlsx_workbook.dart';

/// Onde uma tabela começa numa aba: a linha do cabeçalho e a coluna de "Nome".
class TableLocation {
  const TableLocation({required this.headerRow, required this.startCol});

  final int headerRow;
  final int startCol;
}

/// Resultado de localizar as duas tabelas desta entrega numa aba. Qualquer
/// uma pode não ter sido encontrada (`null`).
class TableLocations {
  const TableLocations({
    this.despesasGerais,
    this.entradaDeValor,
    this.servedBy,
    this.fallbackNote,
  });

  final TableLocation? despesasGerais;
  final TableLocation? entradaDeValor;

  /// Quem respondeu, quando há mais de um provedor em jogo.
  final String? servedBy;

  /// Preenchida quando o provedor principal falhou e a reserva respondeu —
  /// a reserva costuma ser paga, então a tela precisa avisar.
  final String? fallbackNote;

  TableLocations withServedBy(String provider, {String? fallbackNote}) =>
      TableLocations(
        despesasGerais: despesasGerais,
        entradaDeValor: entradaDeValor,
        servedBy: provider,
        fallbackNote: fallbackNote,
      );
}

/// Localiza as tabelas "Despesas Gerais" e "Entrada de Valor" numa aba,
/// usando um LLM para entender a estrutura em vez de heurística de posição.
///
/// **Só recebe rótulos de texto da aba** (via [describeTextCells]) — nunca
/// valores ou datas de lançamento. A extração de fato continua em código
/// determinístico (`readTableRows`), a partir da célula já tipada.
abstract class LlmTableLocator {
  /// Nome do provedor, para mensagens ("Groq", "Anthropic").
  String get providerName;

  Future<TableLocations> locate(SheetGrid grid, {required String sheetName});
}

/// Um localizador que sabe **testar a si mesmo**: o botão "Testar" das
/// configurações de IA.
///
/// O teste manda uma frase curta, sem nada da planilha, e gasta poucos tokens.
/// Só roda quando o usuário aperta; sem repetição automática, para o erro
/// aparecer na hora e o custo ficar previsível.
abstract interface class PingableLocator implements LlmTableLocator {
  /// Quanto a resposta demorou. Falha com [LlmLocatorException] de mensagem
  /// pronta para a tela (ver [pingFailureMessage]).
  Future<Duration> ping();
}

/// Frase mínima do teste: nenhum dado do usuário sai do aparelho.
const String pingPrompt = 'Responda apenas: ok';

/// Tokens que o teste pode gastar na resposta.
const int pingMaxTokens = 16;

/// Traduz o status HTTP de um teste em algo que o usuário entende e sabe
/// corrigir. Só o status decide: o corpo da resposta varia por serviço.
String pingFailureMessage(String provider, int status) => switch (status) {
  401 || 403 => '$provider recusou a chave. Confira se ela foi copiada inteira.',
  404 =>
    '$provider não achou o modelo ou o endereço. Confira o nome do modelo e o '
        'endereço base.',
  429 =>
    '$provider atingiu o limite de uso. A chave parece certa; tente de novo '
        'daqui a pouco.',
  >= 500 => '$provider está fora do ar no momento. Tente de novo mais tarde.',
  _ => '$provider respondeu $status. Confira chave, modelo e endereço.',
};

/// Mensagem do teste quando a chamada nem chegou ao serviço.
String pingConnectionMessage(String provider) =>
    'Sem conexão com $provider. Confira a internet e o endereço.';

/// Falha ao falar com o provedor de LLM: chave ausente, rede fora, resposta
/// de erro ou resposta fora do formato pedido. Mensagem já pronta para a tela.
class LlmLocatorException implements Exception {
  const LlmLocatorException(
    this.message, {
    this.retryable = false,
    this.missingKey = false,
  });

  /// Nenhum provedor tem chave configurada.
  factory LlmLocatorException.noKey(String message) =>
      LlmLocatorException(message, missingKey: true);

  /// Erro do lado do provedor **e passageiro** (sobrecarga, limite de taxa,
  /// rede) — vale tentar de novo. Chave errada, modelo inexistente e resposta
  /// malformada não são: repetir só atrasa o erro de verdade.
  factory LlmLocatorException.http(String provider, int status, String body) =>
      LlmLocatorException(
        '$provider respondeu $status: $body',
        retryable: status == 429 || status == 503 || status == 529,
      );

  final String message;
  final bool retryable;

  /// Falha por falta de chave (e não por erro do provedor): a tela pode
  /// oferecer levar o usuário até onde a chave é configurada.
  final bool missingKey;

  @override
  String toString() => message;
}

/// A instrução mandada ao LLM, igual nas três implementações — o que muda de
/// um provedor para outro é só como a resposta estruturada é pedida.
///
/// A regra de desempate é posicional de propósito: na planilha real, "Gastos
/// Recorrentes" tem **o mesmo cabeçalho** de "Despesas Gerais" e nenhuma das
/// duas tem título em cima, então a única diferença é que Despesas Gerais vem
/// primeiro (mais à esquerda).
String buildLocatePrompt(SheetGrid grid, String sheetName) =>
    '''
Esta é a aba "$sheetName" de uma planilha de finanças pessoais. Abaixo estão
apenas as células de texto dela, no formato COLUNA+LINHA="conteúdo" (coluna em
letra como no Excel, linha 1-based).

Preciso localizar duas tabelas:

1. "Despesas Gerais" — cabeçalho com as colunas, nesta ordem:
   Nome, Valor, Tipo, Banco, Observação, Dia.
2. "Entrada de Valor" — cabeçalho com as colunas, nesta ordem:
   Nome, Valor, Banco, Observação, Dia (sem a coluna "Tipo").

Cuidados:
- A aba também costuma ter uma tabela "Gastos Recorrentes" com **o mesmo
  cabeçalho** de Despesas Gerais. Quando houver duas tabelas com esse mesmo
  cabeçalho, a que estiver **mais à esquerda** é Despesas Gerais; a outra é
  Gastos Recorrentes e deve ser ignorada.
- A aba também tem uma tabela de faturas de cartão, cujo cabeçalho começa com
  "Nome" mas segue com Anterior, Atual, Vencimento, Até, Opção, Valor Pago,
  Restante. Ela não é nenhuma das duas que eu quero — ignore.
- Pode haver blocos soltos (Ganhos, Bancos, Total Mês, Projeção) que também
  não são tabelas de lançamento.

Para cada uma das duas tabelas, responda a linha do cabeçalho (1-based, como
aparece acima) e a coluna onde ela começa (a coluna do "Nome"), em índice
0-based: A=0, B=1, C=2, e assim por diante.

Se alguma das duas não existir nesta aba, devolva null para ela.

Células de texto da aba:
${describeTextCells(grid)}
''';

/// Descreve, em texto, só as células com texto de uma aba — linha, coluna e
/// valor. É o suficiente para um LLM achar onde cada tabela começa (os
/// cabeçalhos são sempre texto) sem nunca ver um valor ou data de lançamento.
String describeTextCells(SheetGrid grid) {
  final lines = <String>[];
  for (var r = 1; r <= grid.maxRow; r++) {
    final row = grid.row(r);
    final textCells = [
      for (final entry in row.entries)
        if (entry.value is XlsxText)
          '${columnIndexToLetter(entry.key)}$r="${(entry.value as XlsxText).value}"',
    ];
    if (textCells.isNotEmpty) lines.add(textCells.join(', '));
  }
  return lines.join('\n');
}

/// A IA não achou uma das duas tabelas na aba (nem na segunda tentativa).
class TablesNotFoundException implements Exception {
  const TablesNotFoundException({required this.despesasFound, required this.entradaFound});

  final bool despesasFound;
  final bool entradaFound;

  /// O nome das tabelas que faltaram, para a mensagem.
  String get missing => [
    if (!despesasFound) '"Despesas Gerais"',
    if (!entradaFound) '"Entrada de Valor"',
  ].join(' e ');

  @override
  String toString() => 'Tabela(s) não encontrada(s) nesta aba: $missing.';
}

/// Localiza as tabelas via [locator] e extrai as linhas de cada uma
/// (`readTableRows`, determinístico) a partir da célula já tipada da [grid].
///
/// [note] vem preenchida quando a reserva respondeu no lugar do provedor
/// principal. Retry e reserva são responsabilidade do próprio [locator]
/// (`RetryingTableLocator`/`FallbackTableLocator`).
Future<({SpreadsheetTables tables, String? note})> extractTablesWithAi(
  SheetGrid grid, {
  required String sheetName,
  required LlmTableLocator locator,
}) async {
  var locations = await locator.locate(grid, sheetName: sheetName);
  // A resposta de um LLM varia: na planilha real, a mesma aba teve a Entrada de
  // Valor não encontrada numa chamada e encontrada na seguinte. Uma segunda
  // tentativa custa centavos e evita um erro à toa.
  if (locations.despesasGerais == null || locations.entradaDeValor == null) {
    locations = await locator.locate(grid, sheetName: sheetName);
  }
  final despesas = locations.despesasGerais;
  final entrada = locations.entradaDeValor;
  if (despesas == null || entrada == null) {
    throw TablesNotFoundException(despesasFound: despesas != null, entradaFound: entrada != null);
  }

  final tables = SpreadsheetTables(
    despesasGerais: readTableRows(
      grid,
      despesas.headerRow,
      despesas.startCol,
      despesasGeraisHeader.length,
    ),
    entradaDeValor: readTableRows(
      grid,
      entrada.headerRow,
      entrada.startCol,
      entradaDeValorHeader.length,
    ),
  );
  return (tables: tables, note: locations.fallbackNote);
}
