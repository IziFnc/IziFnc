import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';
import 'package:izifnc/features/import/domain/parsed_row.dart';

import '../../../tool/corpus.dart';

/// Devolve exatamente o que o `.esperado.json` diz — como se a IA tivesse
/// acertado. Assim este teste exercita só a parte determinística (leitor de
/// .xlsx -> leitura de linhas -> interpretação), sem rede e sem custo.
class _ExpectedLocator implements LlmTableLocator {
  _ExpectedLocator(this.expectation);
  final SheetExpectation expectation;

  @override
  String get providerName => 'esperado';

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async => expectation.locations;
}

int _sum(Iterable<ParsedRow> rows) => rows.fold(0, (a, r) => a + r.valorCents);

void main() {
  // Só o corpus público (fictício, versionado): o resultado não pode depender
  // da máquina. As planilhas reais em `_local/planilhas/` entram na avaliação
  // ao vivo (`tool/avaliar_ia.dart`), não aqui.
  final warnings = <String>[];
  final cases = loadCorpus(dirs: const [publicCorpusDir], warnings: warnings);

  test('o corpus público existe e todas as planilhas têm o .esperado.json', () {
    expect(cases, isNotEmpty, reason: 'rode: dart run tool/gerar_planilhas_exemplo.dart');
    expect(warnings, isEmpty);
  });

  for (final c in cases) {
    group(c.slug, () {
      for (final entry in c.abas.entries) {
        final sheet = entry.key;
        final expected = entry.value;

        test('aba "$sheet"${c.limiteConhecido ? ' (limite conhecido)' : ''}', () async {
          final grid = c.open().readSheet(sheet);
          final result = await extractTablesWithAi(
            grid,
            sheetName: sheet,
            locator: _ExpectedLocator(expected),
          );
          final parsed = parseSheet(result.tables);

          if (c.limiteConhecido) {
            // Documenta o limite: o leitor assume a ordem Nome|Valor|Tipo|...
            // Se um dia passar a dar conta, este teste avisa para promover o
            // caso a "suportado" (tirar o limiteConhecido do JSON).
            expect(
              parsed.rowErrors,
              isNotEmpty,
              reason: 'o leitor agora lê este layout: remova "limiteConhecido" do .esperado.json',
            );
            return;
          }

          final n = expected.contagens;
          expect(parsed.despesas, hasLength(n['despesas']), reason: 'despesas');
          expect(parsed.entradas, hasLength(n['entradas']), reason: 'entradas');
          expect(parsed.transfers, hasLength(n['transfers']), reason: 'transferências');
          expect(parsed.billPayments, hasLength(n['billPayments']), reason: 'pagamentos de fatura');
          expect(parsed.mirrorsConsumed, n['mirrorsConsumed'], reason: 'espelhos consumidos');
          expect(parsed.rowErrors, hasLength(n['rowErrors']), reason: parsed.rowErrors.join('\n'));

          final t = expected.totaisCents;
          expect(_sum(parsed.despesas), t['despesas'], reason: 'total de despesas');
          expect(_sum(parsed.entradas), t['entradas'], reason: 'total de entradas');
          expect(_sum(parsed.transfers), t['transfers'], reason: 'total de transferências');
          expect(_sum(parsed.billPayments), t['billPayments'], reason: 'total de faturas');
        });
      }
    });
  }
}
