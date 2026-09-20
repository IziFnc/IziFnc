import '../data/spreadsheet_tables.dart';
import '../data/xlsx_workbook.dart';

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
  });

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

  ParsedRow copyWith({bool? suspiciousDate}) => ParsedRow(
    sheetRow: sheetRow,
    nome: nome,
    valorCents: valorCents,
    data: data,
    banco: banco,
    tipo: tipo,
    observacao: observacao,
    suspiciousDate: suspiciousDate ?? this.suspiciousDate,
    kind: kind,
    destino: destino,
  );
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

/// Saída de transferência ainda sem o destino resolvido.
class _PendingTransfer {
  _PendingTransfer({
    required this.sheetRow,
    required this.valorCents,
    required this.data,
    required this.banco,
    required this.destino,
  });

  final int sheetRow;
  final int valorCents;
  final DateTime data;
  final String banco;
  final String? destino;
}

/// Linha `transfer` de Entrada de Valor: o lado que **recebe**.
class _Mirror {
  _Mirror({
    required this.sheetRow,
    required this.valorCents,
    required this.data,
    required this.banco,
    required this.observacao,
  });

  final int sheetRow;
  final int valorCents;
  final DateTime? data;
  final String banco;
  final String? observacao;
  bool used = false;
}

/// Interpreta as tabelas já localizadas.
///
/// - `fatura` (Despesas): conta = `Banco`, cartão = `Observação`. Sem ambiguidade.
/// - `transfer` (Despesas): origem = `Banco`, destino = `Observação`. Se o
///   destino estiver em branco, é completado pelo espelho em Entrada de Valor
///   (mesmo valor); se isso não for possível **sem chutar**, vira erro.
/// - `transfer` (Entrada): é o espelho da saída — usado só para casar e
///   completar. Espelho sem saída correspondente vira erro.
///
/// Na planilha real cada transferência aparece duas vezes (saída em Despesas,
/// entrada em Entrada de Valor) e o lado de Entrada é o menos confiável (uma
/// das quatro estava sem data), por isso a fonte é sempre o lado Despesas.
ParsedSheetData parseSheet(SpreadsheetTables tables) {
  final errors = <String>[];
  final pendings = <_PendingTransfer>[];
  final mirrors = <_Mirror>[];
  final billPayments = <ParsedRow>[];

  bool isTransferName(String normalized) => normalized == 'transfer' || normalized.startsWith('transferencia');
  bool isFaturaName(String normalized) => normalized == 'fatura';

  ParsedRow? parseDespesa(RawTableRow row) {
    final nome = _text(row[0]);
    if (nome == null) return null; // linha sem nome: não é um lançamento

    final normalizedNome = normalizeBankName(nome);
    final tipoRaw = _text(row[2]);
    final normalizedTipo = tipoRaw == null ? '' : normalizeBankName(tipoRaw);
    final valor = _cents(row[1]);
    final banco = _text(row[3]);
    final observacao = _text(row[4]);
    final data = _date(row[5]);

    if (isFaturaName(normalizedNome)) {
      if (valor == null || banco == null || data == null || observacao == null) {
        errors.add(
          'Linha ${row.sheetRow} (Despesas Gerais, fatura): faltou valor, conta, '
          'data ou o cartão (Observação) — ignorada.',
        );
        return null;
      }
      billPayments.add(
        ParsedRow(
          sheetRow: row.sheetRow,
          nome: nome,
          valorCents: valor,
          data: data,
          banco: banco,
          tipo: SourceTipo.debito,
          observacao: null,
          suspiciousDate: false,
          kind: ParsedKind.billPayment,
          destino: observacao,
        ),
      );
      return null;
    }

    if (isTransferName(normalizedNome) || isTransferName(normalizedTipo)) {
      if (valor == null || banco == null || data == null) {
        errors.add(
          'Linha ${row.sheetRow} (Despesas Gerais, transfer): faltou valor, '
          'origem ou data — ignorada.',
        );
        return null;
      }
      pendings.add(
        _PendingTransfer(
          sheetRow: row.sheetRow,
          valorCents: valor,
          data: data,
          banco: banco,
          destino: observacao,
        ),
      );
      return null;
    }

    final tipo = _parseTipo(normalizedTipo);
    if (valor == null || banco == null || data == null || tipo == null) {
      errors.add(
        'Linha ${row.sheetRow} (Despesas Gerais, "$nome"): '
        'faltou valor, banco, data ou o Tipo não é Débito/Crédito — ignorada.',
      );
      return null;
    }

    return ParsedRow(
      sheetRow: row.sheetRow,
      nome: nome,
      valorCents: valor,
      data: data,
      banco: banco,
      tipo: tipo,
      observacao: observacao,
      suspiciousDate: false,
    );
  }

  ParsedRow? parseEntrada(RawTableRow row) {
    final nome = _text(row[0]);
    if (nome == null) return null;

    final normalizedNome = normalizeBankName(nome);
    final valor = _cents(row[1]);
    final banco = _text(row[2]);
    final data = _date(row[4]);

    if (isTransferName(normalizedNome)) {
      if (valor == null || banco == null) {
        errors.add(
          'Linha ${row.sheetRow} (Entrada de Valor, transfer): faltou valor ou '
          'conta — ignorada.',
        );
        return null;
      }
      mirrors.add(
        _Mirror(
          sheetRow: row.sheetRow,
          valorCents: valor,
          data: data,
          banco: banco,
          observacao: _text(row[3]),
        ),
      );
      return null;
    }
    if (isFaturaName(normalizedNome)) {
      errors.add(
        'Linha ${row.sheetRow} (Entrada de Valor, fatura): pagamento de fatura '
        'não é esperado em Entrada de Valor — ignorada.',
      );
      return null;
    }

    if (valor == null || banco == null || data == null) {
      errors.add(
        'Linha ${row.sheetRow} (Entrada de Valor, "$nome"): '
        'faltou valor, banco ou data — ignorada.',
      );
      return null;
    }

    return ParsedRow(
      sheetRow: row.sheetRow,
      nome: nome,
      valorCents: valor,
      data: data,
      banco: banco,
      tipo: null,
      observacao: _text(row[3]),
      suspiciousDate: false,
      kind: ParsedKind.income,
    );
  }

  final despesas = [for (final row in tables.despesasGerais) ?parseDespesa(row)];
  final entradas = [for (final row in tables.entradaDeValor) ?parseEntrada(row)];
  final transfers = _resolveTransfers(pendings, mirrors, errors);

  final all = [...despesas, ...entradas, ...transfers, ...billPayments];
  final mirrorsConsumed = mirrors.where((m) => m.used).length;
  for (final m in mirrors.where((m) => !m.used)) {
    errors.add(
      'Linha ${m.sheetRow} (Entrada de Valor, transfer): transferência recebida '
      'sem saída correspondente em Despesas Gerais — ignorada.',
    );
  }

  if (all.isEmpty) {
    return ParsedSheetData(
      despesas: despesas,
      entradas: entradas,
      transfers: transfers,
      billPayments: billPayments,
      mirrorsConsumed: mirrorsConsumed,
      rowErrors: errors,
    );
  }

  final allDates = [for (final r in all) r.data]..sort();
  final median = allDates[allDates.length ~/ 2];
  bool suspicious(DateTime d) => d.difference(median).abs().inDays > 40;
  List<ParsedRow> flag(List<ParsedRow> rows) => [
    for (final r in rows) r.copyWith(suspiciousDate: suspicious(r.data)),
  ];

  return ParsedSheetData(
    despesas: flag(despesas),
    entradas: flag(entradas),
    transfers: flag(transfers),
    billPayments: flag(billPayments),
    mirrorsConsumed: mirrorsConsumed,
    rowErrors: errors,
  );
}

/// Casa cada saída de transferência com o espelho em Entrada de Valor.
///
/// Quem já tem destino escolhe primeiro (só consome o espelho); quem não tem
/// completa o destino com o `Banco` do espelho — e **só** quando há uma
/// resposta inequívoca. Sem espelho, ou com espelhos que apontam para contas
/// diferentes, a linha vira erro: melhor apontar do que gravar uma
/// transferência para a conta errada.
List<ParsedRow> _resolveTransfers(
  List<_PendingTransfer> pendings,
  List<_Mirror> mirrors,
  List<String> errors,
) {
  bool sameName(String? a, String? b) => a != null && b != null && normalizeBankName(a) == normalizeBankName(b);
  bool sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  List<_Mirror> candidatesFor(_PendingTransfer t) => [
    for (final m in mirrors)
      if (!m.used &&
          m.valorCents == t.valorCents &&
          (t.destino == null || sameName(m.banco, t.destino)) &&
          (m.observacao == null || sameName(m.observacao, t.banco)))
        m,
  ]..sort((a, b) => (sameDay(b.data, t.data) ? 1 : 0) - (sameDay(a.data, t.data) ? 1 : 0));

  final byRow = <int, ParsedRow>{};

  ParsedRow build(_PendingTransfer t, String destino) => ParsedRow(
    sheetRow: t.sheetRow,
    nome: 'transfer',
    valorCents: t.valorCents,
    data: t.data,
    banco: t.banco,
    tipo: SourceTipo.debito,
    observacao: null,
    suspiciousDate: false,
    kind: ParsedKind.transfer,
    destino: destino,
  );

  void accept(_PendingTransfer t, String destino) {
    if (sameName(t.banco, destino)) {
      errors.add(
        'Linha ${t.sheetRow} (Despesas Gerais, transfer): origem e destino são '
        'a mesma conta ($destino) — ignorada.',
      );
      return;
    }
    byRow[t.sheetRow] = build(t, destino);
  }

  // 1º: quem já sabe o destino (só reserva o espelho, se existir).
  for (final t in pendings.where((t) => t.destino != null)) {
    final candidates = candidatesFor(t);
    if (candidates.isNotEmpty) candidates.first.used = true;
    accept(t, t.destino!);
  }

  // 2º: quem precisa do espelho para descobrir o destino.
  for (final t in pendings.where((t) => t.destino == null)) {
    final candidates = candidatesFor(t);
    if (candidates.isEmpty) {
      errors.add(
        'Linha ${t.sheetRow} (Despesas Gerais, transfer): destino em branco e '
        'nenhuma entrada com o mesmo valor em Entrada de Valor — ignorada.',
      );
      continue;
    }
    final destinos = {for (final m in candidates) normalizeBankName(m.banco)};
    if (destinos.length > 1) {
      errors.add(
        'Linha ${t.sheetRow} (Despesas Gerais, transfer): destino em branco e '
        'mais de uma entrada com o mesmo valor apontando para contas diferentes — '
        'ignorada (não dá para saber qual é).',
      );
      continue;
    }
    candidates.first.used = true;
    accept(t, candidates.first.banco);
  }

  return [for (final r in (byRow.keys.toList()..sort())) byRow[r]!];
}

String? _text(XlsxValue value) => switch (value) {
  XlsxText(:final value) when value.trim().isNotEmpty => value.trim(),
  _ => null,
};

/// Aceita número (o caso normal) ou texto numérico ("50,00") — algumas
/// células da planilha podem ter sido digitadas como texto.
int? _cents(XlsxValue value) {
  final number = switch (value) {
    XlsxNumber(:final value) => value,
    XlsxText(:final value) => double.tryParse(value.trim().replaceAll(',', '.')),
    _ => null,
  };
  return number == null ? null : (number.abs() * 100).round();
}

/// Aceita célula-data (o caso normal) ou número puro — se o estilo da célula
/// não foi reconhecido como data mas a coluna só pode ser uma data (Dia),
/// ainda dá para converter pelo valor serial.
DateTime? _date(XlsxValue value) => switch (value) {
  XlsxDate(:final value) => value,
  XlsxNumber(:final value) => excelSerialToDate(value),
  _ => null,
};

SourceTipo? _parseTipo(String normalized) => switch (normalized) {
  'debito' => SourceTipo.debito,
  'credito' => SourceTipo.credito,
  _ => null,
};
