import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart' show columnIndexToLetter;

/// Uma célula a gravar: [row] 1-based, [col] 0-based (A=0), como em `SheetGrid`.
/// [value] é `String`, `num` ou `DateTime` (gravado como data do Excel).
class WCell {
  const WCell(this.row, this.col, this.value);

  final int row;
  final int col;
  final Object value;
}

/// Grava um `.xlsx` mínimo mas **válido** (abre no Excel/LibreOffice/Sheets):
/// tipos de conteúdo, relações, estilos, textos compartilhados e uma planilha
/// por aba. Serve só para gerar planilhas **fictícias** de teste.
///
/// Os bytes são determinísticos (data dos arquivos do zip fixa): regerar sem
/// mudar nada não produz diff no git.
Uint8List writeXlsx(Map<String, List<WCell>> sheets) {
  final strings = <String, int>{};
  int stringIndex(String s) => strings.putIfAbsent(s, () => strings.length);

  final sheetNames = sheets.keys.toList();
  final sheetXmls = <String>[];
  for (final name in sheetNames) {
    sheetXmls.add(_sheetXml(sheets[name]!, stringIndex));
  }

  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes)..lastModTime = 946684800);
  }

  add('[Content_Types].xml', _contentTypes(sheetNames.length));
  add('_rels/.rels', _rootRels);
  add('xl/workbook.xml', _workbookXml(sheetNames));
  add('xl/_rels/workbook.xml.rels', _workbookRels(sheetNames.length));
  add('xl/styles.xml', _stylesXml);
  add('xl/sharedStrings.xml', _sharedStringsXml(strings.keys.toList()));
  for (var i = 0; i < sheetXmls.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', sheetXmls[i]);
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

const _xmlHeader = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const _mainNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _relNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _pkgRelNs = 'http://schemas.openxmlformats.org/package/2006/relationships';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Dias desde 1899-12-30 (o mesmo epoch que `excelSerialToDate` desfaz).
int _serial(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1899, 12, 30)).inDays;

String _sheetXml(List<WCell> cells, int Function(String) stringIndex) {
  final byRow = <int, List<WCell>>{};
  for (final c in cells) {
    (byRow[c.row] ??= []).add(c);
  }
  final b = StringBuffer('$_xmlHeader<worksheet xmlns="$_mainNs"><sheetData>');
  for (final r in byRow.keys.toList()..sort()) {
    b.write('<row r="$r">');
    for (final c in byRow[r]!..sort((a, b) => a.col.compareTo(b.col))) {
      final ref = '${columnIndexToLetter(c.col)}$r';
      final v = c.value;
      if (v is String) {
        b.write('<c r="$ref" t="s"><v>${stringIndex(v)}</v></c>');
      } else if (v is DateTime) {
        b.write('<c r="$ref" s="1"><v>${_serial(v)}</v></c>'); // s=1: formato de data
      } else if (v is num) {
        b.write('<c r="$ref"><v>$v</v></c>');
      } else {
        throw ArgumentError('Valor de célula não suportado: $v');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

String _contentTypes(int sheetCount) {
  final b = StringBuffer('$_xmlHeader<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
    ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
    ..write('<Default Extension="xml" ContentType="application/xml"/>')
    ..write('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>')
    ..write('<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>')
    ..write('<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>');
  for (var i = 1; i <= sheetCount; i++) {
    b.write('<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
  }
  b.write('</Types>');
  return b.toString();
}

const _rootRels =
    '$_xmlHeader<Relationships xmlns="$_pkgRelNs">'
    '<Relationship Id="rId1" Type="$_relNs/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbookXml(List<String> names) {
  final b = StringBuffer('$_xmlHeader<workbook xmlns="$_mainNs" xmlns:r="$_relNs"><sheets>');
  for (var i = 0; i < names.length; i++) {
    b.write('<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
  }
  b.write('</sheets></workbook>');
  return b.toString();
}

String _workbookRels(int sheetCount) {
  final b = StringBuffer('$_xmlHeader<Relationships xmlns="$_pkgRelNs">');
  for (var i = 1; i <= sheetCount; i++) {
    b.write('<Relationship Id="rId$i" Type="$_relNs/worksheet" Target="worksheets/sheet$i.xml"/>');
  }
  b
    ..write('<Relationship Id="rId${sheetCount + 1}" Type="$_relNs/styles" Target="styles.xml"/>')
    ..write('<Relationship Id="rId${sheetCount + 2}" Type="$_relNs/sharedStrings" Target="sharedStrings.xml"/>')
    ..write('</Relationships>');
  return b.toString();
}

/// Dois estilos de célula: 0 = geral, 1 = data (`numFmtId` 14, dd/mm/aaaa).
const _stylesXml =
    '$_xmlHeader<styleSheet xmlns="$_mainNs">'
    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="2">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

String _sharedStringsXml(List<String> strings) {
  final b = StringBuffer('$_xmlHeader<sst xmlns="$_mainNs" count="${strings.length}" uniqueCount="${strings.length}">');
  for (final s in strings) {
    b.write('<si><t xml:space="preserve">${_esc(s)}</t></si>');
  }
  b.write('</sst>');
  return b.toString();
}
