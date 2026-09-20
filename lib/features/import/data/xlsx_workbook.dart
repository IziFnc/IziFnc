import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// O valor de uma célula, já resolvido — nunca uma fórmula.
///
/// Uma célula com fórmula (`<f>`) sempre tem também o **valor em cache**
/// (`<v>`), calculado pelo Excel na última vez que o arquivo foi salvo. É
/// esse valor que se lê aqui; a fórmula em si é ignorada. Reavaliar fórmulas
/// exigiria um motor de cálculo inteiro só para ler alguns números.
sealed class XlsxValue {
  const XlsxValue();
}

class XlsxText extends XlsxValue {
  const XlsxText(this.value);
  final String value;
}

class XlsxNumber extends XlsxValue {
  const XlsxNumber(this.value);
  final double value;
}

/// Uma célula numérica cujo **estilo** é de data (ver [_isDateStyle]). O
/// serial já foi convertido para [DateTime].
class XlsxDate extends XlsxValue {
  const XlsxDate(this.value);
  final DateTime value;
}

class XlsxBlank extends XlsxValue {
  const XlsxBlank();
}

/// A grade de células de uma aba, indexada pelo número da linha e da coluna
/// tal como aparecem no arquivo (linha 1-based, como o `r` do XML; coluna
/// 0-based, A=0).
class SheetGrid {
  SheetGrid(this._cells, this.maxRow);

  final Map<int, Map<int, XlsxValue>> _cells;

  /// A última linha que tem alguma célula preenchida.
  final int maxRow;

  XlsxValue cell(int row, int col) => _cells[row]?[col] ?? const XlsxBlank();

  /// As colunas preenchidas de uma linha, em ordem.
  Map<int, XlsxValue> row(int row) => _cells[row] ?? const {};
}

/// Letras de coluna ("A", "BC") para índice 0-based.
int columnLetterToIndex(String letters) {
  var index = 0;
  for (final rune in letters.runes) {
    index = index * 26 + (rune - 64); // 'A' = 65
  }
  return index - 1;
}

/// Índice de coluna 0-based para letras ("A", "BC") — o inverso de
/// [columnLetterToIndex]. Usado para descrever posições de forma legível
/// (para humanos e para o LLM que localiza tabelas).
String columnIndexToLetter(int index) {
  var n = index + 1;
  var letters = '';
  while (n > 0) {
    final remainder = (n - 1) % 26;
    letters = String.fromCharCode(65 + remainder) + letters;
    n = (n - 1) ~/ 26;
  }
  return letters;
}

/// Lê um `.xlsx` já carregado em memória.
///
/// Não usa um pacote de leitura de planilha pronto: a análise de uma planilha
/// real de uso (feita à parte, em notas privadas) exige ler o valor em
/// cache das fórmulas e diferenciar célula-data de célula-número pelo
/// **estilo**, e a forma mais segura de garantir isso é ler o XML na mão —
/// exatamente a lógica já validada manualmente (script Python) durante a
/// análise, portada aqui.
class XlsxWorkbook {
  XlsxWorkbook._(this._archive, this._sheetTargets, this._sharedStrings, this._dateStyleIndices);

  final Archive _archive;
  final Map<String, String> _sheetTargets; // nome da aba -> caminho dentro de xl/
  final List<String> _sharedStrings;
  final Set<int> _dateStyleIndices;

  static const _relNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static XlsxWorkbook open(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    String textOf(String path) {
      final file = archive.findFile(path);
      if (file == null) throw FormatException('$path não encontrado no .xlsx');
      // utf8.decode, não String.fromCharCodes: as partes de um .xlsx são UTF-8,
      // e fromCharCodes trataria cada byte como um code unit (Latin-1), virando
      // "macarrÃ£o" no lugar de "macarrão" — e, pior, fazendo "Crédito" deixar
      // de casar com o tipo esperado na hora de interpretar a linha.
      return utf8.decode(file.readBytes()!);
    }

    // xl/_rels/workbook.xml.rels: r:id -> caminho relativo a xl/
    final relsDoc = XmlDocument.parse(textOf('xl/_rels/workbook.xml.rels'));
    final targetById = <String, String>{
      for (final rel in relsDoc.findAllElements('Relationship'))
        rel.getAttribute('Id')!: rel.getAttribute('Target')!,
    };

    // xl/workbook.xml: ordem das abas (como aparecem no Excel) + r:id de cada uma
    final workbookDoc = XmlDocument.parse(textOf('xl/workbook.xml'));
    final sheetTargets = <String, String>{};
    for (final sheet in workbookDoc.findAllElements('sheet')) {
      final name = sheet.getAttribute('name')!;
      final rId = sheet.getAttribute('id', namespaceUri: _relNs)!;
      var target = targetById[rId]!;
      if (!target.startsWith('xl/')) target = 'xl/$target';
      sheetTargets[name] = target;
    }

    // xl/sharedStrings.xml: strings reaproveitadas por várias células (é assim
    // que o Excel evita repetir texto igual em todo lugar).
    final sharedStrings = <String>[];
    if (archive.findFile('xl/sharedStrings.xml') != null) {
      final doc = XmlDocument.parse(textOf('xl/sharedStrings.xml'));
      for (final si in doc.findAllElements('si')) {
        sharedStrings.add(si.findAllElements('t').map((t) => t.innerText).join());
      }
    }

    final dateStyles = archive.findFile('xl/styles.xml') != null
        ? _computeDateStyleIndices(textOf('xl/styles.xml'))
        : <int>{};

    return XlsxWorkbook._(archive, sheetTargets, sharedStrings, dateStyles);
  }

  /// Na ordem das abas do arquivo (a ordem em que aparecem no Excel).
  List<String> get sheetNames => _sheetTargets.keys.toList();

  SheetGrid readSheet(String name) {
    final target = _sheetTargets[name];
    if (target == null) throw ArgumentError('Aba "$name" não existe.');
    final file = _archive.findFile(target);
    if (file == null) throw FormatException('$target não encontrado.');

    final doc = XmlDocument.parse(utf8.decode(file.readBytes()!));
    final cells = <int, Map<int, XlsxValue>>{};
    var maxRow = 0;

    for (final rowEl in doc.findAllElements('row')) {
      final rowIndex = int.parse(rowEl.getAttribute('r')!);
      maxRow = rowIndex > maxRow ? rowIndex : maxRow;
      final rowCells = <int, XlsxValue>{};

      for (final c in rowEl.findElements('c')) {
        final ref = c.getAttribute('r')!;
        final col = columnLetterToIndex(
          RegExp(r'^[A-Z]+').firstMatch(ref)!.group(0)!,
        );
        final type = c.getAttribute('t');
        final styleIndex = int.tryParse(c.getAttribute('s') ?? '') ?? 0;
        final value = _readCellValue(c, type, styleIndex);
        if (value is! XlsxBlank) rowCells[col] = value;
      }

      if (rowCells.isNotEmpty) cells[rowIndex] = rowCells;
    }

    return SheetGrid(cells, maxRow);
  }

  XlsxValue _readCellValue(XmlElement c, String? type, int styleIndex) {
    if (type == 'inlineStr') {
      final text = c.findElements('is').firstOrNull?.findAllElements('t').map((t) => t.innerText).join();
      return text == null || text.isEmpty ? const XlsxBlank() : XlsxText(text);
    }

    // Fórmula ou número: o valor sempre vem do <v> em cache, nunca do <f>.
    final v = c.findElements('v').firstOrNull?.innerText;
    if (v == null || v.isEmpty) return const XlsxBlank();

    if (type == 's') {
      final index = int.parse(v);
      return index < _sharedStrings.length ? XlsxText(_sharedStrings[index]) : const XlsxBlank();
    }
    if (type == 'str') return XlsxText(v); // resultado textual de fórmula

    final number = double.tryParse(v);
    if (number == null) return const XlsxBlank();
    if (_dateStyleIndices.contains(styleIndex)) {
      return XlsxDate(excelSerialToDate(number));
    }
    return XlsxNumber(number);
  }

  /// Quais índices de estilo (`cellXfs`) representam data, pelo `numFmtId`.
  ///
  /// Ids embutidos do Excel (14-22, 45-47) são sempre data/hora. Formatos
  /// personalizados são inspecionados pelo código (`dd/mm/yyyy` etc.) — a
  /// mesma heurística já validada na análise da planilha (procura por `d`,
  /// `m` ou `y` no código, sem ser um formato numérico puro tipo `"0.00"`).
  static Set<int> _computeDateStyleIndices(String stylesXml) {
    const builtinDateFormats = {14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47};
    final doc = XmlDocument.parse(stylesXml);

    final customFormats = <int, String>{
      for (final fmt in doc.findAllElements('numFmt'))
        int.parse(fmt.getAttribute('numFmtId')!): fmt.getAttribute('formatCode')!,
    };

    final cellXfs = doc.findAllElements('cellXfs').firstOrNull?.findElements('xf').toList() ?? const [];
    final dateStyles = <int>{};
    for (var i = 0; i < cellXfs.length; i++) {
      final numFmtId = int.tryParse(cellXfs[i].getAttribute('numFmtId') ?? '0') ?? 0;
      if (builtinDateFormats.contains(numFmtId)) {
        dateStyles.add(i);
        continue;
      }
      final code = customFormats[numFmtId]?.toLowerCase();
      if (code != null && RegExp(r'[dmy]{2}').hasMatch(code) && !code.startsWith('0')) {
        dateStyles.add(i);
      }
    }
    return dateStyles;
  }
}

/// Data serial do Excel (dias desde 1899-12-30) para [DateTime].
///
/// O epoch é 1899-12-30, não 1899-12-31: isso já absorve o "dia 29/02/1900"
/// fantasma que o Excel inclui por compatibilidade com o Lotus 1-2-3.
/// Confirmado na análise da planilha (`46010` → `2025-12-19`).
DateTime excelSerialToDate(double serial) =>
    DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
