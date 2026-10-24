import '../data/spreadsheet_tables.dart';
import '../data/xlsx_workbook.dart';
import 'parsed_row.dart';
import 'pending_transfer.dart';
import 'sheet_cells.dart';

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
  final pendings = <PendingTransfer>[];
  final mirrors = <TransferMirror>[];
  final billPayments = <ParsedRow>[];

  bool isTransferName(String normalized) => normalized == 'transfer' || normalized.startsWith('transferencia');
  bool isFaturaName(String normalized) => normalized == 'fatura';

  ParsedRow? parseDespesa(RawTableRow row) {
    final nome = cellText(row[0]);
    if (nome == null) return null; // linha sem nome: não é um lançamento

    final normalizedNome = normalizeBankName(nome);
    final tipoRaw = cellText(row[2]);
    final normalizedTipo = tipoRaw == null ? '' : normalizeBankName(tipoRaw);
    final valor = cellCents(row[1]);
    final banco = cellText(row[3]);
    final observacao = cellText(row[4]);
    final data = cellDate(row[5]);

    if (isFaturaName(normalizedNome)) {
      if (valor == null || banco == null) {
        errors.add(
          'Linha ${row.sheetRow} (Despesas Gerais, fatura): faltou valor ou a '
          'conta que pagou — ignorada.',
        );
        return null;
      }
      // Sem data e sem o cartão ainda entram (feat 0025): a data vem do mês da
      // aba e o cartão é perguntado no mapeamento — ver [unknownCardName].
      billPayments.add(
        ParsedRow(
          sheetRow: row.sheetRow,
          nome: nome,
          valorCents: valor,
          data: data ?? noDateYet,
          banco: banco,
          tipo: SourceTipo.debito,
          observacao: null,
          suspiciousDate: false,
          kind: ParsedKind.billPayment,
          destino: observacao ?? unknownCardName(banco),
          undated: data == null,
          cardUnknown: observacao == null,
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
        PendingTransfer(
          sheetRow: row.sheetRow,
          valorCents: valor,
          data: data,
          banco: banco,
          destino: observacao,
        ),
      );
      return null;
    }

    final tipo = parseTipo(normalizedTipo);
    if (valor == null || banco == null || tipo == null) {
      errors.add(
        'Linha ${row.sheetRow} (Despesas Gerais, "$nome"): '
        'faltou valor, banco ou o Tipo não é Débito/Crédito — ignorada.',
      );
      return null;
    }

    return ParsedRow(
      sheetRow: row.sheetRow,
      nome: nome,
      valorCents: valor,
      data: data ?? noDateYet,
      banco: banco,
      tipo: tipo,
      observacao: observacao,
      suspiciousDate: false,
      undated: data == null,
      lastInstallment: switch (row[4]) {
        // Número na faixa de datas do Excel (anos ~1982–2064): data sem formato.
        XlsxNumber(:final value) when value >= 30000 && value <= 60000 => excelSerialToDate(value),
        XlsxDate(:final value) => value,
        _ => null,
      },
    );
  }

  ParsedRow? parseEntrada(RawTableRow row) {
    final nome = cellText(row[0]);
    if (nome == null) return null;

    final normalizedNome = normalizeBankName(nome);
    final valor = cellCents(row[1]);
    final banco = cellText(row[2]);
    final data = cellDate(row[4]);

    if (isTransferName(normalizedNome)) {
      if (valor == null || banco == null) {
        errors.add(
          'Linha ${row.sheetRow} (Entrada de Valor, transfer): faltou valor ou '
          'conta — ignorada.',
        );
        return null;
      }
      mirrors.add(
        TransferMirror(
          sheetRow: row.sheetRow,
          valorCents: valor,
          data: data,
          banco: banco,
          observacao: cellText(row[3]),
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

    if (valor == null || banco == null) {
      errors.add(
        'Linha ${row.sheetRow} (Entrada de Valor, "$nome"): '
        'faltou valor ou banco — ignorada.',
      );
      return null;
    }

    return ParsedRow(
      sheetRow: row.sheetRow,
      nome: nome,
      valorCents: valor,
      data: data ?? noDateYet,
      banco: banco,
      tipo: null,
      observacao: cellText(row[3]),
      suspiciousDate: false,
      kind: ParsedKind.income,
      undated: data == null,
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

  // As datas da aba dizem qual é o "mês da aba". Só as linhas que TÊM data
  // entram na conta; as sem data recebem uma depois.
  final dated = [for (final r in all) if (!r.undated) r.data]..sort();
  if (dated.isEmpty) {
    // Nenhuma data na aba: não há mês para usar nas linhas sem data.
    for (final r in all.where((r) => r.undated)) {
      errors.add(
        'Linha ${r.sheetRow} ("${r.nome}"): sem data, e a aba não tem nenhuma '
        'outra data para usar — ignorada.',
      );
    }
    return ParsedSheetData(
      despesas: const [],
      entradas: const [],
      transfers: transfers,
      billPayments: const [],
      mirrorsConsumed: mirrorsConsumed,
      rowErrors: errors,
    );
  }

  final median = dated[dated.length ~/ 2];
  bool suspicious(DateTime d) => d.difference(median).abs().inDays > 40;
  // O intervalo "normal" da aba (sem as datas suspeitas): a última data é o
  // "fim do mês da aba" das linhas sem data (decisão do dono), e nenhuma data
  // ajustada sai dele — assim o lançamento cai no mesmo mês que os outros.
  final normal = dated.where((d) => !suspicious(d)).toList();
  final first = normal.isEmpty ? median : normal.first;
  final last = normal.isEmpty ? median : normal.last;

  ParsedRow resolve(ParsedRow r) {
    if (r.undated) return r.copyWith(data: last, suspiciousDate: false);
    if (!suspicious(r.data)) return r.copyWith(suspiciousDate: false);
    // Parcela copiada mês a mês com a data da compra original: é um gasto
    // DESTE mês — mesmo dia no mês da aba, dentro das datas da aba. No formato
    // antigo, só se o parcelamento ainda corre no mês da aba.
    final ended = r.lastInstallment != null &&
        !parcelaPattern.hasMatch(r.observacao?.trim() ?? '') &&
        r.lastInstallment!.isBefore(first.subtract(const Duration(days: 3)));
    if (r.isParcela && !ended) {
      final lastDay = DateTime(median.year, median.month + 1, 0).day;
      var moved = DateTime(median.year, median.month, r.data.day > lastDay ? lastDay : r.data.day);
      if (moved.isBefore(first)) moved = first;
      if (moved.isAfter(last)) moved = last;
      return r.copyWith(data: moved, originalDate: r.data, suspiciousDate: false);
    }
    return r.copyWith(suspiciousDate: true);
  }

  List<ParsedRow> resolveAll(List<ParsedRow> rows) => [for (final r in rows) resolve(r)];

  return ParsedSheetData(
    despesas: resolveAll(despesas),
    entradas: resolveAll(entradas),
    transfers: resolveAll(transfers),
    billPayments: resolveAll(billPayments),
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
  List<PendingTransfer> pendings,
  List<TransferMirror> mirrors,
  List<String> errors,
) {
  bool sameName(String? a, String? b) => a != null && b != null && normalizeBankName(a) == normalizeBankName(b);
  bool sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  List<TransferMirror> candidatesFor(PendingTransfer t) => [
    for (final m in mirrors)
      if (!m.used &&
          m.valorCents == t.valorCents &&
          (t.destino == null || sameName(m.banco, t.destino)) &&
          (m.observacao == null || sameName(m.observacao, t.banco)))
        m,
  ]..sort((a, b) => (sameDay(b.data, t.data) ? 1 : 0) - (sameDay(a.data, t.data) ? 1 : 0));

  final byRow = <int, ParsedRow>{};

  ParsedRow build(PendingTransfer t, String destino) => ParsedRow(
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

  void accept(PendingTransfer t, String destino) {
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
