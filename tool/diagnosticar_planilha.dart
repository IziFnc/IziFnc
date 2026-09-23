// Diagnóstico da importação numa planilha REAL, aba por aba: mostra onde cada
// linha das tabelas vai parar (lançamento, erro, espelho de transferência,
// desmarcada por data suspeita, ignorada por não ter Nome, fora do corte de
// leitura) — para achar por que uma importação trouxe menos linhas que a planilha.
//
//   dart run tool/diagnosticar_planilha.dart [caminho.xlsx] [--aba NOME]
//
// Sem caminho, usa o primeiro .xlsx de _local/jason/ ou _local/planilhas/.
// Chama a IA uma vez por aba (como o app), com as chaves de GROQ_API_KEY /
// ANTHROPIC_API_KEY ou _local/keys/{groq,anthropic}.txt. Custa centavos.
//
// PRIVACIDADE: o console mostra só CONTAGENS. O detalhe (número da linha +
// motivo, sem valores nem descrições) vai para _local/eval/, que nunca é versionado.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:izifnc/features/import/data/anthropic_table_locator.dart';
import 'package:izifnc/features/import/data/fallback_table_locator.dart';
import 'package:izifnc/features/import/data/groq_table_locator.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/spreadsheet_tables.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';
import 'package:izifnc/features/import/domain/parsed_row.dart';

String? _readKey(String env, String fileName) {
  final fromEnv = Platform.environment[env];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
  final file = File('_local/keys/$fileName.txt');
  if (file.existsSync()) {
    final text = file.readAsStringSync().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String? _text(XlsxValue v) => v is XlsxText && v.value.trim().isNotEmpty ? v.value.trim() : null;

bool _blank(List<XlsxValue> values) => values.every((v) => v is XlsxBlank);

/// Linhas com algum conteúdo nas colunas da tabela DEPOIS de onde a leitura parou
/// (3 brancos seguidos): o que o app nunca chegou a ler.
List<int> _rowsAfterCut(SheetGrid grid, List<RawTableRow> read, int headerRow, int startCol, int cols) {
  final last = read.isEmpty ? headerRow : read.last.sheetRow;
  // A leitura pára 3 linhas depois da última lida; olha daí até o fim.
  return [
    for (var r = last + 4; r <= grid.maxRow; r++)
      if (!_blank([for (var c = 0; c < cols; c++) grid.cell(r, startCol + c)])) r,
  ];
}

/// Outras colunas "Nome" na linha do cabeçalho (ex.: Gastos Recorrentes), fora das
/// duas tabelas lidas.
List<int> _otherNameColumns(SheetGrid grid, int headerRow, Set<int> known) => [
  for (var c = 0; c < 80; c++)
    if (!known.contains(c) && (_text(grid.cell(headerRow, c))?.toLowerCase() == 'nome')) c,
];

final _parcela = RegExp(r'^\d+\s*/\s*\d+$');

String _kind(XlsxValue v) => switch (v) {
  XlsxBlank() => 'vazia',
  XlsxText() => 'texto',
  XlsxNumber() => 'número',
  XlsxDate() => 'data',
};

bool _numeric(XlsxValue v) =>
    v is XlsxNumber || (v is XlsxText && double.tryParse(v.value.trim().replaceAll('.', '').replaceAll(',', '.')) != null);

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll('í', 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c')
    .trim();

/// Por que uma linha de Despesas Gerais falharia: campo + tipo da célula, nunca o conteúdo.
/// Colunas: 0 Nome, 1 Valor, 2 Tipo, 3 Banco, 4 Observação, 5 Dia.
List<String> _despesaProblems(RawTableRow r) {
  final nome = _norm(_text(r[0]) ?? '');
  final tipo = _norm(_text(r[2]) ?? '');
  final isFatura = nome == 'fatura';
  final isTransfer = nome == 'transfer' || nome.startsWith('transferencia') || tipo == 'transfer' || tipo.startsWith('transferencia');
  return [
    if (!_numeric(r[1])) 'Valor(${_kind(r[1])})',
    if (_text(r[3]) == null) 'Banco(${_kind(r[3])})',
    if (r[5] is! XlsxDate && r[5] is! XlsxNumber) 'Dia(${_kind(r[5])})',
    if (isFatura && _text(r[4]) == null) 'Observação/cartão(${_kind(r[4])})',
    if (!isFatura && !isTransfer && tipo != 'debito' && tipo != 'credito') 'Tipo(${tipo.isEmpty ? _kind(r[2]) : 'texto "$tipo"'})',
  ];
}

const _vocabulario = {'fatura', 'transfer', 'debito', 'credito', 'pix', 'boleto', 'dinheiro'};

/// O "formato" da linha, sem conteúdo: tipo de cada célula; em Nome/Tipo/Observação
/// só aparece o texto quando é palavra do vocabulário da planilha (fatura, débito…)
/// ou o padrão de parcela "n/N".
String _shape(RawTableRow r, List<String> header) => [
  for (var i = 0; i < header.length; i++)
    '${header[i]}:${switch (r[i]) {
      XlsxText(:final value) when _vocabulario.contains(_norm(value)) || _norm(value).startsWith('transferencia') =>
        '"${_norm(value)}"',
      XlsxText(:final value) when _parcela.hasMatch(value.trim()) => 'parcela',
      final v => _kind(v),
    }}',
].join(' ');

/// Colunas: 0 Nome, 1 Valor, 2 Banco, 3 Observação, 4 Dia.
List<String> _entradaProblems(RawTableRow r) => [
  if (!_numeric(r[1])) 'Valor(${_kind(r[1])})',
  if (_text(r[2]) == null) 'Banco(${_kind(r[2])})',
  if (r[4] is! XlsxDate && r[4] is! XlsxNumber) 'Dia(${_kind(r[4])})',
];

Future<int> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final positional = [
    for (var i = 0; i < args.length; i++)
      if (!args[i].startsWith('--') && (i == 0 || !args[i - 1].startsWith('--'))) args[i],
  ];
  var path = positional.isEmpty ? null : positional.first;
  if (path == null) {
    for (final dir in ['_local/jason', '_local/planilhas']) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      final found = d.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.xlsx')).toList();
      if (found.isNotEmpty) {
        path = found.first.path;
        break;
      }
    }
  }
  if (path == null || !File(path).existsSync()) {
    stderr.writeln('Planilha não encontrada. Passe o caminho: dart run tool/diagnosticar_planilha.dart arquivo.xlsx');
    return 2;
  }

  final groqKey = _readKey('GROQ_API_KEY', 'groq');
  final anthropicKey = _readKey('ANTHROPIC_API_KEY', 'anthropic');
  if (groqKey == null && anthropicKey == null) {
    stderr.writeln('Sem chave de IA (defina GROQ_API_KEY ou crie _local/keys/groq.txt).');
    return 2;
  }
  final client = http.Client();
  final locator = FallbackTableLocator([
    if (groqKey != null) RetryingTableLocator(GroqTableLocator(client: client, apiKey: groqKey)),
    if (anthropicKey != null) RetryingTableLocator(AnthropicTableLocator(client: client, apiKey: anthropicKey)),
  ]);

  final workbook = XlsxWorkbook.open(File(path).readAsBytesSync());
  final onlySheet = opt('aba');
  final sheets = [for (final s in workbook.sheetNames) if (onlySheet == null || s == onlySheet) s];

  final report = StringBuffer()
    ..writeln('# Diagnóstico da importação — ${DateTime.now().toIso8601String().substring(0, 16)}')
    ..writeln()
    ..writeln('Arquivo: `${path.split(RegExp(r'[\\/]')).last}` · ${sheets.length} aba(s)')
    ..writeln()
    ..writeln('Só números de linha e motivos; nenhum valor ou descrição.')
    ..writeln();

  final problemTotals = <String, int>{};
  stdout.writeln('Planilha: ${path.split(RegExp(r'[\\/]')).last} (${sheets.length} aba(s))\n');
  stdout.writeln('${'aba'.padRight(14)}lidas  semNome  erros  espelho  lanç  datSusp(parc)  foraCorte  outrasTab');

  for (final sheet in sheets) {
    final grid = workbook.readSheet(sheet);
    TableLocations loc;
    try {
      loc = await locator.locate(grid, sheetName: sheet);
    } catch (e) {
      stdout.writeln('${sheet.padRight(14)}IA falhou: ${e.toString().split('\n').first}');
      report.writeln('## $sheet\n\nA IA falhou ao localizar: `${e.toString().split('\n').first}`\n');
      continue;
    }
    final d = loc.despesasGerais;
    final e = loc.entradaDeValor;
    if (d == null || e == null) {
      // Onde há rótulos de cabeçalho nesta aba (só rótulos conhecidos, nada de conteúdo).
      const labels = {'nome', 'valor', 'tipo', 'banco', 'observacao', 'dia', 'entrada de valor', 'despesas gerais'};
      final found = <String>[];
      for (var r = 1; r <= grid.maxRow && r <= 60; r++) {
        for (var c = 0; c < 40; c++) {
          final t = _text(grid.cell(r, c));
          if (t != null && labels.contains(_norm(t))) found.add('L${r}C$c=${_norm(t)}');
        }
      }
      stdout.writeln('${sheet.padRight(14)}tabelas não encontradas (D=${d != null} E=${e != null})');
      report.writeln('## $sheet\n\nTabelas não encontradas (Despesas=${d != null}, Entrada=${e != null}).\n'
          'Rótulos de cabeçalho achados: ${found.join(' ')}\n');
      continue;
    }

    final desp = readTableRows(grid, d.headerRow, d.startCol, despesasGeraisHeader.length);
    final entr = readTableRows(grid, e.headerRow, e.startCol, entradaDeValorHeader.length);
    final parsed = parseSheet(SpreadsheetTables(despesasGerais: desp, entradaDeValor: entr));

    final noNameD = [for (final r in desp) if (_text(r[0]) == null) r.sheetRow];
    final noNameE = [for (final r in entr) if (_text(r[0]) == null) r.sheetRow];
    final cutD = _rowsAfterCut(grid, desp, d.headerRow, d.startCol, despesasGeraisHeader.length);
    final cutE = _rowsAfterCut(grid, entr, e.headerRow, e.startCol, entradaDeValorHeader.length);

    final all = [...parsed.despesas, ...parsed.entradas, ...parsed.transfers, ...parsed.billPayments];
    final susp = [for (final r in all) if (r.suspiciousDate) r];
    final suspParcela = susp.where((r) => _parcela.hasMatch(r.observacao ?? '')).length;

    // Tabelas "Nome" a mais na linha do cabeçalho (Gastos Recorrentes etc.): quantas
    // linhas com Nome elas têm — o app não as lê de propósito.
    final others = _otherNameColumns(grid, d.headerRow, {d.startCol, e.startCol});
    var otherRows = 0;
    for (final c in others) {
      otherRows += readTableRows(grid, d.headerRow, c, 6).where((r) => _text(r[0]) != null).length;
    }

    final headerOkD = _text(grid.cell(d.headerRow, d.startCol))?.toLowerCase() == 'nome';
    final headerOkE = _text(grid.cell(e.headerRow, e.startCol))?.toLowerCase() == 'nome';

    stdout.writeln(
      sheet.padRight(14) +
          '${desp.length + entr.length}'.padLeft(5) +
          '${noNameD.length + noNameE.length}'.padLeft(9) +
          '${parsed.rowErrors.length}'.padLeft(7) +
          '${parsed.mirrorsConsumed}'.padLeft(9) +
          '${all.length}'.padLeft(6) +
          '${susp.length} ($suspParcela)'.padLeft(15) +
          '${cutD.length + cutE.length}'.padLeft(11) +
          '$otherRows'.padLeft(11) +
          (headerOkD && headerOkE ? '' : '  ⚠ cabeçalho sem "Nome" na célula apontada'),
    );

    report
      ..writeln('## $sheet')
      ..writeln()
      ..writeln('- Despesas Gerais: cabeçalho L${d.headerRow}/C${d.startCol} ${headerOkD ? '(Nome ✓)' : '(⚠ sem "Nome")'}; '
          '${desp.length} linha(s) lidas, última L${desp.isEmpty ? '-' : desp.last.sheetRow}')
      ..writeln('- Entrada de Valor: cabeçalho L${e.headerRow}/C${e.startCol} ${headerOkE ? '(Nome ✓)' : '(⚠ sem "Nome")'}; '
          '${entr.length} linha(s) lidas, última L${entr.isEmpty ? '-' : entr.last.sheetRow}')
      ..writeln('- Viram lançamento: ${parsed.despesas.length} despesas, ${parsed.entradas.length} entradas, '
          '${parsed.transfers.length} transferências, ${parsed.billPayments.length} pagamentos de fatura = **${all.length}**')
      ..writeln('- Espelhos de transferência (a mesma transferência na Entrada de Valor, contada uma vez): '
          '${parsed.mirrorsConsumed}')
      ..writeln('- Sem Nome (ignoradas sem aviso): Despesas ${noNameD.isEmpty ? '-' : noNameD.map((r) => 'L$r').join(', ')}; '
          'Entrada ${noNameE.isEmpty ? '-' : noNameE.map((r) => 'L$r').join(', ')}')
      ..writeln('- Data suspeita (entram DESMARCADAS na prévia): ${susp.length}, das quais parcelas "n/N": $suspParcela — '
          '${susp.isEmpty ? '-' : susp.map((r) => 'L${r.sheetRow}').join(', ')}')
      ..writeln('- Com conteúdo depois do corte de leitura (nunca lidas): Despesas ${cutD.isEmpty ? '-' : cutD.map((r) => 'L$r').join(', ')}; '
          'Entrada ${cutE.isEmpty ? '-' : cutE.map((r) => 'L$r').join(', ')}')
      ..writeln('- Outras tabelas com coluna "Nome" na mesma linha (ex.: Gastos Recorrentes, fora de propósito): '
          '${others.isEmpty ? '-' : 'colunas ${others.join(', ')}, $otherRows linha(s)'}')
      ..writeln('- Erros (${parsed.rowErrors.length}):');
    for (final err in parsed.rowErrors) {
      // A mensagem do app cita o Nome da linha entre aspas: mascarado aqui.
      report.writeln('  - ${err.replaceAll(RegExp(r'"[^"]*"'), '"…"')}');
    }
    // Qual campo falha em cada linha com erro (campo e tipo da célula, sem conteúdo).
    final errorRows = {
      for (final err in parsed.rowErrors) int.tryParse(RegExp(r'Linha (\d+)').firstMatch(err)?.group(1) ?? ''),
    };
    // Formato das linhas que continuam com data suspeita (desmarcadas na prévia).
    final suspRows = {for (final r in susp) r.sheetRow};
    report.writeln('- Formato das linhas com data suspeita:');
    for (final r in desp.where((r) => suspRows.contains(r.sheetRow))) {
      final obs = r[4];
      final dia = r[5];
      // Observação numérica: é uma data serial do Excel sem formato de data? Só a
      // faixa e a distância até o intervalo normal da aba, nunca o valor.
      var meses = '';
      if (obs is XlsxNumber) {
        final n = obs.value;
        if (n >= 30000 && n <= 60000 && dia is XlsxDate) {
          final asDate = DateTime(1899, 12, 30).add(Duration(days: n.floor()));
          final okDates = [for (final r2 in all) if (!r2.suspiciousDate) r2.data]..sort();
          final inRange = okDates.isNotEmpty &&
              !asDate.isBefore(okDates.first.subtract(const Duration(days: 3))) &&
              !asDate.isAfter(okDates.last.add(const Duration(days: 3)));
          meses = ' (Observação = data serial; ${inRange ? 'DENTRO' : 'fora'} das datas normais da aba; '
              'Dia ${asDate.difference(dia.value).inDays ~/ 30} mês(es) antes)';
        } else {
          meses = ' (Observação numérica fora da faixa de datas: ${n < 1 ? '<1' : n < 100 ? '<100' : '>=100'})';
        }
      }
      report.writeln('  - L${r.sheetRow} Despesas — ${_shape(r, despesasGeraisHeader)}$meses');
    }
    report.writeln('- Campo que falhou em cada linha com erro:');
    for (final (i, r) in desp.indexed) {
      if (!errorRows.contains(r.sheetRow)) continue;
      final p = [
        ..._despesaProblems(r),
        // Linha sem data logo abaixo de uma com data: seria "o mesmo dia de cima"?
        if (r[5] is XlsxBlank && i > 0 && (desp[i - 1][5] is XlsxDate || desp[i - 1][5] is XlsxNumber))
          'acima-tem-data',
      ];
      report.writeln('  - L${r.sheetRow} Despesas: ${p.isEmpty ? '(nenhum campo vazio: ver regra de transferência)' : p.join(', ')}'
          ' — ${_shape(r, despesasGeraisHeader)}');
      for (final x in p) {
        problemTotals[x] = (problemTotals[x] ?? 0) + 1;
      }
    }
    for (final r in entr) {
      if (!errorRows.contains(r.sheetRow)) continue;
      final p = _entradaProblems(r);
      report.writeln('  - L${r.sheetRow} Entrada: ${p.isEmpty ? '(nenhum campo vazio: ver regra de transferência)' : p.join(', ')}'
          ' — ${_shape(r, entradaDeValorHeader)}');
      for (final x in p) {
        problemTotals[x] = (problemTotals[x] ?? 0) + 1;
      }
    }
    report.writeln();
  }
  client.close();

  if (problemTotals.isNotEmpty) {
    stdout.writeln('\nCampos que causaram erro (todas as abas):');
    for (final e in (problemTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))) {
      stdout.writeln('  ${e.value.toString().padLeft(3)}  ${e.key}');
    }
  }

  final outDir = Directory('_local/eval')..createSync(recursive: true);
  final out = File('${outDir.path}/diagnostico-${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '')}.md');
  out.writeAsStringSync(report.toString());
  stdout.writeln('\nlidas = linhas com algo nas colunas das duas tabelas; lanç = o que o app importaria;');
  stdout.writeln('datSusp = entram desmarcadas na prévia (entre parênteses, quantas são parcelas "n/N").');
  stdout.writeln('Detalhe por linha (sem valores): ${out.path}');
  return 0;
}
