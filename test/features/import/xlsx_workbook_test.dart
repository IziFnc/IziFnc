import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

/// Monta um `.xlsx` mínimo a partir das partes XML que o [XlsxWorkbook]
/// realmente lê — sem `[Content_Types].xml` nem `_rels/.rels`, que um leitor
/// de verdade exigiria mas o nosso não usa. É o suficiente para testar o
/// parser de ponta a ponta sem depender de um arquivo binário versionado.
Uint8List buildXlsx({
  required String sheetXml,
  String sheetName = 'Aba1',
  String? sharedStringsXml,
  String? stylesXml,
}) {
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('xl/workbook.xml', '''
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
              xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets><sheet name="$sheetName" sheetId="1" r:id="rId1"/></sheets>
    </workbook>
  ''');
  add('xl/_rels/workbook.xml.rels', '''
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Target="worksheets/sheet1.xml"/>
    </Relationships>
  ''');
  add('xl/worksheets/sheet1.xml', sheetXml);
  if (sharedStringsXml != null) add('xl/sharedStrings.xml', sharedStringsXml);
  if (stylesXml != null) add('xl/styles.xml', stylesXml);

  return ZipEncoder().encodeBytes(archive);
}

/// Índice de coluna 0-based -> letra ("A", "B", ..., "Z", "AA").
String columnLetter(int index) {
  var n = index + 1;
  var letters = '';
  while (n > 0) {
    final rem = (n - 1) % 26;
    letters = String.fromCharCode(65 + rem) + letters;
    n = (n - 1) ~/ 26;
  }
  return letters;
}

void main() {
  group('XlsxWorkbook — tipos de célula', () {
    test('texto compartilhado, número, data, fórmula e texto embutido', () {
      final bytes = buildXlsx(
        sheetName: 'Dezembro',
        sharedStringsXml: '''
          <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
               count="1" uniqueCount="1">
            <si><t>Bradesco</t></si>
          </sst>
        ''',
        stylesXml: '''
          <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <cellXfs count="2">
              <xf numFmtId="0"/>
              <xf numFmtId="14"/>
            </cellXfs>
          </styleSheet>
        ''',
        sheetXml: '''
          <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
              <row r="1">
                <c r="A1" t="s"><v>0</v></c>
                <c r="B1"><v>42.5</v></c>
                <c r="C1" s="1"><v>46010</v></c>
                <c r="D1"><f>1+1</f><v>2</v></c>
                <c r="E1" t="inlineStr"><is><t>Nota</t></is></c>
              </row>
            </sheetData>
          </worksheet>
        ''',
      );

      final workbook = XlsxWorkbook.open(bytes);
      expect(workbook.sheetNames, ['Dezembro']);
      final grid = workbook.readSheet('Dezembro');

      expect((grid.cell(1, 0) as XlsxText).value, 'Bradesco');
      expect((grid.cell(1, 1) as XlsxNumber).value, 42.5);
      // 46010 já foi verificado manualmente durante a análise da planilha:
      // corresponde a 2025-12-19 (epoch 1899-12-30).
      expect((grid.cell(1, 2) as XlsxDate).value, DateTime(2025, 12, 19));
      expect(
        (grid.cell(1, 3) as XlsxNumber).value,
        2,
        reason: 'valor em cache da fórmula, nunca reavaliada',
      );
      expect((grid.cell(1, 4) as XlsxText).value, 'Nota');
      expect(grid.cell(1, 5), isA<XlsxBlank>());
    });

    test('estilo de data por código customizado (dd/mm/yyyy)', () {
      final bytes = buildXlsx(
        stylesXml: '''
          <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <numFmts count="1">
              <numFmt numFmtId="164" formatCode="dd/mm/yyyy"/>
            </numFmts>
            <cellXfs count="1"><xf numFmtId="164"/></cellXfs>
          </styleSheet>
        ''',
        sheetXml: '''
          <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
              <row r="1"><c r="A1" s="0"><v>46010</v></c></row>
            </sheetData>
          </worksheet>
        ''',
      );

      final grid = XlsxWorkbook.open(bytes).readSheet('Aba1');
      expect((grid.cell(1, 0) as XlsxDate).value, DateTime(2025, 12, 19));
    });

    test('sem sharedStrings.xml nem styles.xml (aba só com números)', () {
      final bytes = buildXlsx(
        sheetXml: '''
          <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData><row r="1"><c r="A1"><v>10</v></c></row></sheetData>
          </worksheet>
        ''',
      );
      final grid = XlsxWorkbook.open(bytes).readSheet('Aba1');
      expect((grid.cell(1, 0) as XlsxNumber).value, 10);
    });

    test('texto acentuado sobrevive à volta pelo zip (UTF-8, não Latin-1)', () {
      // Achado testando com a planilha real: lendo os bytes com
      // String.fromCharCodes, "macarrão" virava "macarrÃ£o" e "Crédito"
      // deixava de casar com o tipo esperado — 26 linhas caíam como erro.
      final bytes = buildXlsx(
        sheetName: 'Dezembro',
        sharedStringsXml: '''
          <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <si><t>macarrão</t></si>
            <si><t>Crédito</t></si>
            <si><t>Observação</t></si>
          </sst>
        ''',
        sheetXml: '''
          <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
              <row r="1">
                <c r="A1" t="s"><v>0</v></c>
                <c r="B1" t="s"><v>1</v></c>
                <c r="C1" t="s"><v>2</v></c>
              </row>
            </sheetData>
          </worksheet>
        ''',
      );

      final grid = XlsxWorkbook.open(bytes).readSheet('Dezembro');
      expect((grid.cell(1, 0) as XlsxText).value, 'macarrão');
      expect((grid.cell(1, 1) as XlsxText).value, 'Crédito');
      expect((grid.cell(1, 2) as XlsxText).value, 'Observação');
    });
  });

  group('columnLetterToIndex', () {
    test('letras simples e duplas', () {
      expect(columnLetterToIndex('A'), 0);
      expect(columnLetterToIndex('Z'), 25);
      expect(columnLetterToIndex('AA'), 26);
    });
  });
}
