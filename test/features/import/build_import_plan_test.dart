import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/import/domain/build_import_plan.dart';
import 'package:izifnc/features/import/domain/import_plan.dart';
import 'package:izifnc/features/import/domain/parsed_row.dart';

final _dia = DateTime(2025, 12, 1);

ParsedRow _row({
  ParsedKind kind = ParsedKind.expense,
  String nome = 'Mercado',
  String banco = 'Bradesco',
  SourceTipo? tipo = SourceTipo.debito,
  String? destino,
  String? observacao,
  int valor = 1000,
  bool suspicious = false,
}) => ParsedRow(
  sheetRow: 1,
  nome: nome,
  valorCents: valor,
  data: _dia,
  banco: banco,
  tipo: tipo,
  observacao: observacao,
  suspiciousDate: suspicious,
  kind: kind,
  destino: destino,
);

ParsedSheetData _data({
  List<ParsedRow> despesas = const [],
  List<ParsedRow> entradas = const [],
  List<ParsedRow> transfers = const [],
  List<ParsedRow> billPayments = const [],
}) => ParsedSheetData(
  despesas: despesas,
  entradas: entradas,
  transfers: transfers,
  billPayments: billPayments,
  rowErrors: const [],
);

Future<bool> _never(EntryDraft _) async => false;

// Planilha real (feat 0025): o que a prévia e o lançamento dizem das regras novas.
void _planilhaReal() {
  group('planilha real', () {
    test('fatura sem cartão: o cartão vem do mapeamento e a descrição não repete o rótulo técnico', () async {
      final fatura = ParsedRow(
        sheetRow: 42,
        nome: 'fatura',
        valorCents: 30000,
        data: _dia,
        banco: 'Bradesco',
        tipo: SourceTipo.debito,
        observacao: null,
        suspiciousDate: false,
        kind: ParsedKind.billPayment,
        destino: unknownCardName('Bradesco'),
        cardUnknown: true,
      );
      final plan = await buildImportPlan(
        parsed: _data(billPayments: [fatura]),
        mapped: {'bradesco|debito': _bradesco, fatura.destinoKey!: _cartaoAmazon},
        isDuplicate: _never,
      );
      final row = plan.rows.single;
      expect(row.toAccountId, _cartaoAmazon);
      expect(row.description, 'Pagamento fatura');
      expect(row.include, isTrue);
    });

    test('parcela trazida para o mês da aba guarda a data da compra na observação', () async {
      final parcela = ParsedRow(
        sheetRow: 3,
        nome: 'Geladeira',
        valorCents: 25000,
        data: _dia,
        banco: 'Amazon',
        tipo: SourceTipo.credito,
        observacao: '4/10',
        suspiciousDate: false,
        originalDate: DateTime(2025, 8, 10),
      );
      final plan = await buildImportPlan(
        parsed: _data(despesas: [parcela]),
        mapped: {'amazon|credito': _cartaoAmazon},
        isDuplicate: _never,
      );
      expect(plan.rows.single.note, '4/10 · compra em 10/08/2025');
      expect(plan.rows.single.include, isTrue);
    });

    test('parcela no formato antigo: a observação diz até quando vai e a data da compra', () async {
      final tv = ParsedRow(
        sheetRow: 3,
        nome: 'TV',
        valorCents: 20000,
        data: _dia,
        banco: 'Amazon',
        tipo: SourceTipo.credito,
        observacao: null,
        suspiciousDate: false,
        originalDate: DateTime(2025, 8, 15),
        lastInstallment: DateTime(2026, 5, 15),
      );
      final plan = await buildImportPlan(
        parsed: _data(despesas: [tv]),
        mapped: {'amazon|credito': _cartaoAmazon},
        isDuplicate: _never,
      );
      expect(plan.rows.single.note, 'parcela até 05/2026 · compra em 15/08/2025');
    });

    test('os avisos da prévia contam cada coisa que a importação fez diferente da planilha', () async {
      ParsedRow r({bool undated = false, DateTime? original, bool semCartao = false, bool suspeita = false}) => ParsedRow(
        sheetRow: 1,
        nome: 'X',
        valorCents: 100,
        data: _dia,
        banco: 'Bradesco',
        tipo: SourceTipo.debito,
        observacao: null,
        suspiciousDate: suspeita,
        undated: undated,
        originalDate: original,
      );
      final parsed = ParsedSheetData(
        despesas: [r(undated: true), r(original: DateTime(2025, 8, 1)), r(suspeita: true), r()],
        entradas: const [],
        mirrorsConsumed: 2,
        rowErrors: const [],
      );
      final plan = await buildImportPlan(parsed: parsed, mapped: {'bradesco|debito': _bradesco}, isDuplicate: _never);

      final notes = importNotes(parsed, plan.rows);
      expect(notes, contains(startsWith('1 vieram desmarcada(s)')));
      expect(notes, contains(startsWith('1 parcela(s)')));
      expect(notes, contains(startsWith('1 linha(s) estavam sem data')));
      expect(notes, contains(startsWith('2 transferência(s) aparecem duas vezes')));
      expect(notes, contains(contains('Gastos Recorrentes')));
      expect(notes.where((n) => n.contains('fatura(s) sem o cartão')), isEmpty, reason: 'só aparece o que aconteceu');
    });

    test('linha sem data na planilha: entra marcada, e a observação avisa', () async {
      final semDia = ParsedRow(
        sheetRow: 60,
        nome: 'Padaria',
        valorCents: 1500,
        data: _dia,
        banco: 'Bradesco',
        tipo: SourceTipo.debito,
        observacao: null,
        suspiciousDate: false,
        undated: true,
      );
      final plan = await buildImportPlan(
        parsed: _data(despesas: [semDia]),
        mapped: {'bradesco|debito': _bradesco},
        isDuplicate: _never,
      );
      expect(plan.rows.single.include, isTrue);
      expect(plan.rows.single.note, 'sem data na planilha');
    });
  });
}

// Ids das contas escolhidas no mapeamento.
const _bradesco = 1;
const _c6 = 2;
const _cartaoAmazon = 3;

void main() {
  _planilhaReal();

  test('despesa e entrada viram expense e income, com a observação como nota', () async {
    final plan = await buildImportPlan(
      parsed: _data(
        despesas: [_row(observacao: 'parcela 2/6')],
        entradas: [_row(kind: ParsedKind.income, nome: 'Salário', tipo: null)],
      ),
      mapped: {'bradesco|debito': _bradesco},
      isDuplicate: _never,
    );

    expect(plan.errors, isEmpty);
    expect(plan.rows.map((r) => r.type), [EntryType.expense, EntryType.income]);
    expect(plan.rows.first.description, 'Mercado');
    expect(plan.rows.first.note, 'parcela 2/6');
    expect(plan.rows.first.toAccountId, isNull);
  });

  test('transferência: origem, destino e a descrição do formulário manual', () async {
    final plan = await buildImportPlan(
      parsed: _data(
        transfers: [_row(kind: ParsedKind.transfer, nome: 'transfer', destino: 'C6', valor: 170000)],
      ),
      mapped: {'bradesco|debito': _bradesco, 'c6|debito': _c6},
      isDuplicate: _never,
    );

    final row = plan.rows.single;
    expect(row.type, EntryType.transfer);
    expect(row.accountId, _bradesco);
    expect(row.toAccountId, _c6);
    expect(row.description, 'Transferência');
    final draft = row.toDraft();
    expect((draft.accountId, draft.toAccountId, draft.amountCents), (_bradesco, _c6, 170000));
  });

  test('fatura: sai da conta e vai para o cartão, com "Pagamento fatura {cartão}"', () async {
    final plan = await buildImportPlan(
      parsed: _data(
        billPayments: [_row(kind: ParsedKind.billPayment, nome: 'fatura', destino: 'Amazon', valor: 80433)],
      ),
      mapped: {'bradesco|debito': _bradesco, 'amazon|credito': _cartaoAmazon},
      isDuplicate: _never,
    );

    final row = plan.rows.single;
    expect(row.type, EntryType.billPayment);
    expect(row.accountId, _bradesco);
    expect(row.toAccountId, _cartaoAmazon);
    expect(row.description, 'Pagamento fatura Amazon');
    expect(row.note, isNull);
  });

  test('duplicata e data suspeita vêm desmarcadas, cada uma com o seu motivo', () async {
    final plan = await buildImportPlan(
      parsed: _data(
        despesas: [
          _row(nome: 'Repetida'),
          _row(nome: 'Data estranha', suspicious: true),
          _row(nome: 'Normal'),
        ],
      ),
      mapped: {'bradesco|debito': _bradesco},
      isDuplicate: (d) async => d.description == 'Repetida',
    );

    final byName = {for (final r in plan.rows) r.description: r};
    expect(byName['Repetida']!.include, isFalse);
    expect(byName['Repetida']!.reason, ImportSkipReason.duplicate);
    expect(byName['Data estranha']!.include, isFalse);
    expect(byName['Data estranha']!.reason, ImportSkipReason.suspiciousDate);
    expect(byName['Normal']!.include, isTrue);
  });

  test('o isDuplicate recebe o destino: transferência e despesa não se confundem', () async {
    final seen = <EntryDraft>[];
    await buildImportPlan(
      parsed: _data(
        transfers: [_row(kind: ParsedKind.transfer, nome: 'transfer', destino: 'C6')],
      ),
      mapped: {'bradesco|debito': _bradesco, 'c6|debito': _c6},
      isDuplicate: (d) async {
        seen.add(d);
        return false;
      },
    );

    expect(seen.single.toAccountId, _c6);
    expect(seen.single.type, EntryType.transfer);
  });

  test('origem e destino mapeados para a mesma conta: erro, não grava', () async {
    final plan = await buildImportPlan(
      parsed: _data(
        transfers: [_row(kind: ParsedKind.transfer, nome: 'transfer', destino: 'C6')],
      ),
      mapped: {'bradesco|debito': _bradesco, 'c6|debito': _bradesco},
      isDuplicate: _never,
    );

    expect(plan.rows, isEmpty);
    expect(plan.errors.single, contains('mesma conta'));
  });

  test('sem mapeamento para o destino: erro, não trava as outras linhas', () async {
    final plan = await buildImportPlan(
      parsed: _data(
        despesas: [_row(nome: 'Mercado')],
        transfers: [_row(kind: ParsedKind.transfer, nome: 'transfer', destino: 'C6')],
      ),
      mapped: {'bradesco|debito': _bradesco},
      isDuplicate: _never,
    );

    expect(plan.rows.single.description, 'Mercado');
    expect(plan.errors.single, contains('sem mapeamento'));
  });

  // Importar só uma parte (feat 0013): o usuário pode dizer "esse banco não" no
  // mapeamento. Essas linhas ficam de fora sem virar erro, e são contadas.
  group('banco marcado como "não importar"', () {
    test('as linhas dele ficam de fora, sem erro, e são contadas', () async {
      final plan = await buildImportPlan(
        parsed: _data(
          despesas: [
            _row(nome: 'Mercado'),
            _row(nome: 'Padaria', banco: 'C6'),
            _row(nome: 'Farmácia', banco: 'C6'),
          ],
        ),
        mapped: {'bradesco|debito': _bradesco},
        skipped: {'c6|debito'},
        isDuplicate: _never,
      );

      expect(plan.rows.map((r) => r.description), ['Mercado']);
      expect(plan.errors, isEmpty, reason: 'foi escolha, não erro');
      expect(plan.leftOutByChoice, 2);
    });

    test('transferência some se a origem OU o destino foram pulados (não dá para importar metade)', () async {
      for (final skipped in [
        {'bradesco|debito'},
        {'c6|debito'},
      ]) {
        final plan = await buildImportPlan(
          parsed: _data(
            transfers: [_row(kind: ParsedKind.transfer, nome: 'transfer', destino: 'C6')],
          ),
          mapped: {'bradesco|debito': _bradesco, 'c6|debito': _c6}..removeWhere((k, _) => skipped.contains(k)),
          skipped: skipped,
          isDuplicate: _never,
        );

        expect(plan.rows, isEmpty, reason: '$skipped');
        expect(plan.errors, isEmpty, reason: '$skipped');
        expect(plan.leftOutByChoice, 1, reason: '$skipped');
      }
    });

    test('pagamento de fatura some se o cartão foi pulado', () async {
      final plan = await buildImportPlan(
        parsed: _data(
          billPayments: [_row(kind: ParsedKind.billPayment, nome: 'fatura', destino: 'Amazon')],
        ),
        mapped: {'bradesco|debito': _bradesco},
        skipped: {'amazon|credito'},
        isDuplicate: _never,
      );

      expect(plan.rows, isEmpty);
      expect(plan.leftOutByChoice, 1);
    });

    test('sem ninguém pulado nada muda: continua contando zero', () async {
      final plan = await buildImportPlan(
        parsed: _data(despesas: [_row()]),
        mapped: {'bradesco|debito': _bradesco},
        isDuplicate: _never,
      );

      expect(plan.rows, hasLength(1));
      expect(plan.leftOutByChoice, 0);
    });
  });

  group('canContinueMapping', () {
    const keys = ['bradesco|debito', 'c6|debito', 'amazon|credito'];

    test('tudo ligado a uma conta: pode continuar (como sempre foi)', () {
      expect(
        canContinueMapping(
          keys: keys,
          mapped: {'bradesco|debito': 1, 'c6|debito': 2, 'amazon|credito': 3},
          skipped: {},
        ),
        isTrue,
      );
    });

    test('parte ligada e o resto marcado "não importar": pode continuar', () {
      expect(
        canContinueMapping(
          keys: keys,
          mapped: {'bradesco|debito': 1},
          skipped: {'c6|debito', 'amazon|credito'},
        ),
        isTrue,
      );
    });

    test('um banco sem decisão (nem conta, nem "não importar") ainda trava', () {
      expect(
        canContinueMapping(
          keys: keys,
          mapped: {'bradesco|debito': 1},
          skipped: {'c6|debito'},
        ),
        isFalse,
      );
    });

    test('pular tudo não importa nada: não deixa continuar', () {
      expect(
        canContinueMapping(keys: keys, mapped: {}, skipped: keys.toSet()),
        isFalse,
      );
    });
  });
}
