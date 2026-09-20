import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/import/data/spreadsheet_tables.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';
import 'package:izifnc/features/import/domain/parsed_row.dart';

RawTableRow despesaRow(
  int sheetRow, {
  required String nome,
  required Object valor,
  required String tipo,
  required String banco,
  String? observacao,
  DateTime? dia,
}) => RawTableRow(sheetRow, [
  XlsxText(nome),
  valor is num ? XlsxNumber(valor.toDouble()) : XlsxText(valor as String),
  XlsxText(tipo),
  XlsxText(banco),
  observacao == null ? const XlsxBlank() : XlsxText(observacao),
  dia == null ? const XlsxBlank() : XlsxDate(dia),
]);

RawTableRow entradaRow(
  int sheetRow, {
  required String nome,
  required Object valor,
  required String banco,
  String? observacao,
  DateTime? dia,
}) => RawTableRow(sheetRow, [
  XlsxText(nome),
  valor is num ? XlsxNumber(valor.toDouble()) : XlsxText(valor as String),
  XlsxText(banco),
  observacao == null ? const XlsxBlank() : XlsxText(observacao),
  dia == null ? const XlsxBlank() : XlsxDate(dia),
]);

SpreadsheetTables tables({List<RawTableRow> despesas = const [], List<RawTableRow> entradas = const []}) =>
    SpreadsheetTables(despesasGerais: despesas, entradaDeValor: entradas);

final dez1 = DateTime(2025, 12, 1);
final dez5 = DateTime(2025, 12, 5);

void main() {
  group('normalizeBankName', () {
    test('remove acento e caixa', () {
      expect(normalizeBankName('Bradesco'), 'bradesco');
      expect(normalizeBankName('BRADESCO'), 'bradesco');
      expect(normalizeBankName(' Débito '), 'debito');
      expect(normalizeBankName('Crédito'), 'credito');
    });
  });

  group('despesas e entradas', () {
    test('lê despesa no débito e no crédito', () {
      final parsed = parseSheet(
        tables(
          despesas: [
            despesaRow(20, nome: 'Mercado', valor: 50.5, tipo: 'Debito', banco: 'Bradesco', dia: dez1),
            despesaRow(21, nome: 'Mouse', valor: 129.99, tipo: 'Crédito', banco: 'Amazon', dia: dez1),
          ],
        ),
      );
      expect(parsed.despesas, hasLength(2));
      expect(parsed.despesas[0].valorCents, 5050);
      expect(parsed.despesas[0].tipo, SourceTipo.debito);
      expect(parsed.despesas[1].tipo, SourceTipo.credito);
      expect(parsed.despesas[1].mappingKey, 'amazon|credito');
      expect(parsed.despesas[0].kind, ParsedKind.expense);
      expect(parsed.rowErrors, isEmpty);
    });

    test('Tipo não reconhecido vira erro de linha, não trava a importação', () {
      final parsed = parseSheet(
        tables(despesas: [despesaRow(9, nome: 'Estranho', valor: 10, tipo: 'boleto', banco: 'Bradesco', dia: dez1)]),
      );
      expect(parsed.despesas, isEmpty);
      expect(parsed.rowErrors.single, contains('Linha 9'));
    });

    test('valor digitado como texto ("50,00") ainda é lido', () {
      final parsed = parseSheet(
        tables(despesas: [despesaRow(1, nome: 'Mercado', valor: '50,00', tipo: 'Debito', banco: 'Bradesco', dia: dez1)]),
      );
      expect(parsed.despesas.single.valorCents, 5000);
    });

    test('Entrada de Valor não tem Tipo — mapeia sempre como débito (conta)', () {
      final entrada = parseSheet(
        tables(entradas: [entradaRow(1, nome: 'Salário', valor: 5000, banco: 'Bradesco', dia: DateTime(2025, 11, 27))]),
      ).entradas.single;
      expect(entrada.tipo, isNull);
      expect(entrada.kind, ParsedKind.income);
      expect(entrada.mappingKey, 'bradesco|debito');
    });
  });

  group('pagamento de fatura', () {
    test('conta = Banco, cartão = Observação; sem ambiguidade', () {
      final parsed = parseSheet(
        tables(
          despesas: [
            despesaRow(28, nome: 'fatura', valor: 804.33, tipo: 'Debito', banco: 'Bradesco', observacao: 'Amazon', dia: dez1),
          ],
        ),
      );
      final fatura = parsed.billPayments.single;
      expect(fatura.kind, ParsedKind.billPayment);
      expect(fatura.valorCents, 80433);
      expect(fatura.mappingKey, 'bradesco|debito', reason: 'a conta que paga');
      expect(fatura.destinoKey, 'amazon|credito', reason: 'o cartão pago');
      expect(parsed.despesas, isEmpty, reason: 'não é despesa');
      expect(parsed.rowErrors, isEmpty);
    });

    test('mesmo nome para a conta e para o cartão continuam sendo coisas distintas', () {
      // Bradesco paga a fatura do cartão Bradesco: as duas chaves diferem no tipo.
      final fatura = parseSheet(
        tables(
          despesas: [
            despesaRow(27, nome: 'fatura', valor: 3251.68, tipo: 'Debito', banco: 'Bradesco', observacao: 'Bradesco', dia: dez1),
          ],
        ),
      ).billPayments.single;
      expect(fatura.mappingKey, 'bradesco|debito');
      expect(fatura.destinoKey, 'bradesco|credito');
    });

    test('sem o cartão (Observação) vira erro, não chute', () {
      final parsed = parseSheet(
        tables(despesas: [despesaRow(3, nome: 'fatura', valor: 100, tipo: 'Debito', banco: 'Bradesco', dia: dez1)]),
      );
      expect(parsed.billPayments, isEmpty);
      expect(parsed.rowErrors.single, allOf(contains('Linha 3'), contains('cartão')));
    });

    test('fatura em Entrada de Valor não é esperada e vira erro', () {
      final parsed = parseSheet(
        tables(entradas: [entradaRow(4, nome: 'fatura', valor: 100, banco: 'Bradesco', dia: dez1)]),
      );
      expect(parsed.billPayments, isEmpty);
      expect(parsed.rowErrors.single, contains('Linha 4'));
    });
  });

  group('transferência', () {
    test('destino vem da Observação; o espelho em Entrada é consumido, não importado', () {
      final parsed = parseSheet(
        tables(
          despesas: [
            despesaRow(29, nome: 'transfer', valor: 450, tipo: 'Debito', banco: 'Bradesco', observacao: 'Caixa', dia: dez1),
          ],
          entradas: [
            entradaRow(21, nome: 'transfer', valor: 450, banco: 'Caixa', observacao: 'Bradesco', dia: dez1),
          ],
        ),
      );
      final t = parsed.transfers.single;
      expect(t.kind, ParsedKind.transfer);
      expect(t.mappingKey, 'bradesco|debito', reason: 'origem');
      expect(t.destinoKey, 'caixa|debito', reason: 'destino');
      expect(parsed.mirrorsConsumed, 1);
      expect(parsed.entradas, isEmpty, reason: 'o espelho não vira entrada — entraria duas vezes');
      expect(parsed.rowErrors, isEmpty);
    });

    test('destino em branco é completado pelo espelho de mesmo valor (caso real: 50 do C6)', () {
      final parsed = parseSheet(
        tables(
          despesas: [despesaRow(56, nome: 'transfer', valor: 50, tipo: 'Debito', banco: 'C6', dia: dez1)],
          entradas: [entradaRow(19, nome: 'transfer', valor: 50, banco: 'Caixa', dia: dez1)],
        ),
      );
      final t = parsed.transfers.single;
      expect(t.mappingKey, 'c6|debito');
      expect(t.destinoKey, 'caixa|debito');
      expect(parsed.rowErrors, isEmpty);
    });

    test('espelho sem data (caso real: o de 1.700) não atrapalha — a data vem da saída', () {
      final parsed = parseSheet(
        tables(
          despesas: [
            despesaRow(31, nome: 'transfer', valor: 1700, tipo: 'Debito', banco: 'Bradesco', observacao: 'C6', dia: dez1),
          ],
          entradas: [entradaRow(22, nome: 'transfer', valor: 1700, banco: 'C6', observacao: 'Bradesco')],
        ),
      );
      expect(parsed.transfers.single.data, dez1);
      expect(parsed.mirrorsConsumed, 1);
      expect(parsed.rowErrors, isEmpty);
    });

    test('destino em branco e nenhum espelho: erro, não chute', () {
      final parsed = parseSheet(
        tables(despesas: [despesaRow(7, nome: 'transfer', valor: 50, tipo: 'Debito', banco: 'C6', dia: dez1)]),
      );
      expect(parsed.transfers, isEmpty);
      expect(parsed.rowErrors.single, allOf(contains('Linha 7'), contains('destino')));
    });

    test('destino em branco e espelhos que apontam para contas diferentes: ambíguo, erro', () {
      final parsed = parseSheet(
        tables(
          despesas: [despesaRow(7, nome: 'transfer', valor: 50, tipo: 'Debito', banco: 'C6', dia: dez1)],
          entradas: [
            entradaRow(1, nome: 'transfer', valor: 50, banco: 'Caixa', dia: dez1),
            entradaRow(2, nome: 'transfer', valor: 50, banco: 'Bradesco', dia: dez1),
          ],
        ),
      );
      expect(parsed.transfers, isEmpty);
      expect(parsed.rowErrors.first, allOf(contains('Linha 7'), contains('não dá para saber')));
    });

    test('quem tem destino escolhe o espelho primeiro; o sem destino fica com o que sobrou', () {
      // Duas saídas de 100: uma diz "Caixa", a outra não diz nada. Há dois
      // espelhos de 100 (Caixa e C6). A do "Caixa" leva o de Caixa; a outra
      // descobre C6 — e não se atrapalham na ordem em que aparecem.
      final parsed = parseSheet(
        tables(
          despesas: [
            despesaRow(1, nome: 'transfer', valor: 100, tipo: 'Debito', banco: 'Bradesco', dia: dez1),
            despesaRow(2, nome: 'transfer', valor: 100, tipo: 'Debito', banco: 'Bradesco', observacao: 'Caixa', dia: dez1),
          ],
          entradas: [
            entradaRow(10, nome: 'transfer', valor: 100, banco: 'Caixa', dia: dez1),
            entradaRow(11, nome: 'transfer', valor: 100, banco: 'C6', dia: dez1),
          ],
        ),
      );
      expect(parsed.rowErrors, isEmpty);
      expect(parsed.transfers, hasLength(2));
      expect(parsed.transfers[0].destinoKey, 'c6|debito', reason: 'linha 1 ficou com o que sobrou');
      expect(parsed.transfers[1].destinoKey, 'caixa|debito');
      expect(parsed.mirrorsConsumed, 2);
    });

    test('espelho sem saída correspondente é apontado, não importado', () {
      final parsed = parseSheet(
        tables(entradas: [entradaRow(5, nome: 'transfer', valor: 999, banco: 'Caixa', dia: dez1)]),
      );
      expect(parsed.transfers, isEmpty);
      expect(parsed.entradas, isEmpty);
      expect(parsed.rowErrors.single, allOf(contains('Linha 5'), contains('sem saída')));
    });

    test('origem igual ao destino é erro', () {
      final parsed = parseSheet(
        tables(
          despesas: [despesaRow(3, nome: 'transfer', valor: 10, tipo: 'Debito', banco: 'C6', observacao: 'c6', dia: dez1)],
        ),
      );
      expect(parsed.transfers, isEmpty);
      expect(parsed.rowErrors.single, contains('mesma conta'));
    });

    test('Tipo "Transferencia" também é transferência', () {
      final parsed = parseSheet(
        tables(
          despesas: [
            despesaRow(4, nome: 'algo', valor: 10, tipo: 'Transferencia', banco: 'Bradesco', observacao: 'C6', dia: dez1),
          ],
        ),
      );
      expect(parsed.transfers, hasLength(1));
    });
  });

  group('mappingPairs', () {
    test('inclui destino de transferência e cartão de fatura, sem repetir', () {
      final parsed = parseSheet(
        tables(
          despesas: [
            despesaRow(1, nome: 'Mercado', valor: 10, tipo: 'Debito', banco: 'Bradesco', dia: dez1),
            despesaRow(2, nome: 'transfer', valor: 5, tipo: 'Debito', banco: 'Bradesco', observacao: 'Caixa', dia: dez1),
            despesaRow(3, nome: 'fatura', valor: 7, tipo: 'Debito', banco: 'Bradesco', observacao: 'Amazon', dia: dez1),
          ],
        ),
      );
      expect(
        [for (final (nome, tipo) in parsed.mappingPairs) '$nome|${tipo.name}'],
        ['Bradesco|debito', 'Caixa|debito', 'Amazon|credito'],
      );
    });
  });

  group('data suspeita', () {
    test('marca linha a mais de 40 dias da mediana das datas da aba', () {
      final parsed = parseSheet(
        tables(
          despesas: [
            despesaRow(1, nome: 'A', valor: 10, tipo: 'Debito', banco: 'Bradesco', dia: dez1),
            despesaRow(2, nome: 'B', valor: 10, tipo: 'Debito', banco: 'Bradesco', dia: dez5),
            // digitado com o ano errado — bem longe da mediana.
            despesaRow(3, nome: 'C', valor: 10, tipo: 'Debito', banco: 'Bradesco', dia: DateTime(2026, 12, 30)),
          ],
        ),
      );
      expect(parsed.despesas[0].suspiciousDate, isFalse);
      expect(parsed.despesas[1].suspiciousDate, isFalse);
      expect(parsed.despesas[2].suspiciousDate, isTrue);
    });
  });
}
