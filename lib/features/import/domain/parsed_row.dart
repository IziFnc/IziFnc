
export 'parse_sheet.dart';

/// Débito ou crédito, como a coluna `Tipo` de Despesas Gerais. Entrada de
/// Valor não tem essa coluna — entrada sempre cai numa conta, nunca cartão.
enum SourceTipo { debito, credito }

/// O que a linha da planilha vira no app.
enum ParsedKind { expense, income, transfer, billPayment }

/// Tira acento e caixa: "Bradesco", "bradesco", "BRADESCO" viram a mesma
/// chave. A planilha não é consistente na grafia (armadilha já documentada
/// na análise da planilha real, feita à parte).
String normalizeBankName(String raw) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  var text = raw.trim().toLowerCase();
  for (var i = 0; i < from.length; i++) {
    text = text.replaceAll(from[i], to[i].toLowerCase());
  }
  return text;
}

/// Chave de mapeamento salva em `import_bank_mappings`: "banco|tipo".
String bankMappingKey(String banco, SourceTipo tipo) => '${normalizeBankName(banco)}|${tipo.name}';

/// O "cartão" de uma fatura cuja linha não diz qual cartão foi pago (Observação
/// vazia). Vira um item do mapeamento — "de qual cartão é a fatura paga pelo
/// Bradesco?" — e a resposta fica lembrada para as próximas abas, como os bancos.
String unknownCardName(String banco) => 'Fatura sem cartão · paga por $banco';

/// Observação no formato de parcela: "4/10", "2 / 6".
final parcelaPattern = RegExp(r'^\d+\s*/\s*\d+$');

/// Linha sem data ainda não resolvida (ver [parseSheet]).
final noDateYet = DateTime(0);

/// Uma linha já interpretada da planilha — pronta para virar um `EntryDraft`,
/// faltando só resolver a conta/cartão.
class ParsedRow {
  const ParsedRow({
    required this.sheetRow,
    required this.nome,
    required this.valorCents,
    required this.data,
    required this.banco,
    required this.tipo,
    required this.observacao,
    required this.suspiciousDate,
    this.kind = ParsedKind.expense,
    this.destino,
    this.undated = false,
    this.originalDate,
    this.cardUnknown = false,
    this.lastInstallment,
  });

  /// Formato antigo de parcela (até abril/2026): a Observação era uma DATA, a da
  /// última parcela, guardada como número. Nulo quando a Observação não é data.
  final DateTime? lastInstallment;

  /// A planilha não tinha data: [data] é a última data da aba (o "fim do mês"
  /// da aba), e a prévia/observação avisam.
  final bool undated;

  /// Parcela ("4/10") que estava com a data da compra original, meses antes:
  /// [data] foi trazida para o mesmo dia no mês da aba, e esta é a data de origem.
  final DateTime? originalDate;

  /// Fatura sem o cartão na Observação: [destino] é [unknownCardName] e o cartão
  /// de verdade vem do mapeamento.
  final bool cardUnknown;

  /// Linha da planilha (1-based) — para a prévia apontar onde está.
  final int sheetRow;
  final String nome;
  final int valorCents;
  final DateTime data;

  /// Em despesa/entrada, a conta ou o cartão. Em transferência, a **origem**;
  /// em pagamento de fatura, a conta que paga.
  final String banco;

  /// `null` em Entrada de Valor.
  final SourceTipo? tipo;
  final String? observacao;

  /// A data está a mais de 40 dias da mediana das datas da aba — provável
  /// erro de digitação (armadilha #3 da análise: datas fora do período).
  /// Vem desmarcada por padrão na prévia.
  final bool suspiciousDate;

  final ParsedKind kind;

  /// Só em transferência (a conta de destino) e pagamento de fatura (o cartão).
  final String? destino;

  /// Débito e Entrada de Valor mapeiam para conta; Crédito, para cartão.
  String get mappingKey => bankMappingKey(banco, tipo ?? SourceTipo.debito);

  /// Chave do destino: outra conta numa transferência, um cartão numa fatura.
  String? get destinoKey => switch (kind) {
    ParsedKind.transfer when destino != null => bankMappingKey(destino!, SourceTipo.debito),
    ParsedKind.billPayment when destino != null => bankMappingKey(destino!, SourceTipo.credito),
    _ => null,
  };

  ParsedRow copyWith({bool? suspiciousDate, DateTime? data, DateTime? originalDate}) => ParsedRow(
    sheetRow: sheetRow,
    nome: nome,
    valorCents: valorCents,
    data: data ?? this.data,
    banco: banco,
    tipo: tipo,
    observacao: observacao,
    suspiciousDate: suspiciousDate ?? this.suspiciousDate,
    kind: kind,
    destino: destino,
    undated: undated,
    originalDate: originalDate ?? this.originalDate,
    cardUnknown: cardUnknown,
    lastInstallment: lastInstallment,
  );

  /// Parcela: "4/10" na Observação, ou (formato antigo) a data da última parcela
  /// depois da data da compra.
  bool get isParcela =>
      parcelaPattern.hasMatch(observacao?.trim() ?? '') ||
      (lastInstallment != null && lastInstallment!.isAfter(data));
}

/// Resultado de interpretar as duas tabelas de uma aba.
class ParsedSheetData {
  const ParsedSheetData({
    required this.despesas,
    required this.entradas,
    this.transfers = const [],
    this.billPayments = const [],
    this.mirrorsConsumed = 0,
    required this.rowErrors,
  });

  final List<ParsedRow> despesas;
  final List<ParsedRow> entradas;

  /// Transferências entre contas, lidas do lado **Despesas** (a saída).
  final List<ParsedRow> transfers;

  /// Pagamentos de fatura: conta -> cartão.
  final List<ParsedRow> billPayments;

  /// Quantas linhas `transfer` de Entrada de Valor (o espelho da entrada)
  /// foram casadas com uma saída e, por isso, não viram lançamento próprio —
  /// senão a transferência entraria duas vezes.
  final int mirrorsConsumed;

  /// Linhas que não puderam ser interpretadas (faltou valor, data ou banco,
  /// tipo desconhecido, destino de transferência que não dá para identificar)
  /// — mostradas à parte na prévia, nunca importadas silenciosamente nem
  /// adivinhadas.
  final List<String> rowErrors;

  List<ParsedRow> get all => [...despesas, ...entradas, ...transfers, ...billPayments];

  /// Cada (nome, tipo) distinto que precisa ser mapeado para uma conta ou
  /// cartão do app, na ordem em que aparecem. Inclui o **destino** das
  /// transferências e o cartão das faturas, que podem não ter nenhuma compra
  /// na aba.
  List<(String, SourceTipo)> get mappingPairs {
    final seen = <String>{};
    final pairs = <(String, SourceTipo)>[];
    void add(String nome, SourceTipo tipo) {
      if (seen.add(bankMappingKey(nome, tipo))) pairs.add((nome, tipo));
    }

    for (final row in all) {
      add(row.banco, row.tipo ?? SourceTipo.debito);
      final destino = row.destino;
      if (destino != null && row.destinoKey != null) {
        add(destino, row.kind == ParsedKind.billPayment ? SourceTipo.credito : SourceTipo.debito);
      }
    }
    return pairs;
  }
}
