import 'xlsx_writer.dart';

/// Uma linha de Despesas Gerais (Nome, Valor, Tipo, Banco, Observação, Dia).
class Despesa {
  const Despesa(this.nome, this.valor, this.tipo, this.banco, {this.obs, this.dia});

  final String nome;
  final double valor;
  final String tipo;
  final String banco;

  /// Texto (ex.: "4/10") ou número (ex.: data serial sem formato de data, o
  /// formato antigo de parcela da planilha real).
  final Object? obs;
  final DateTime? dia;
}

/// Uma linha de Entrada de Valor (Nome, Valor, Banco, Observação, Dia).
class Entrada {
  const Entrada(this.nome, this.valor, this.banco, {this.obs, this.dia});

  final String nome;
  final double valor;
  final String banco;
  final String? obs;
  final DateTime? dia;
}

/// Um modelo de planilha fictícia: as abas a gravar e a verdade esperada de
/// cada uma (onde ficam as tabelas e o que o leitor determinístico deve achar).
class GeneratedCase {
  const GeneratedCase({
    required this.slug,
    required this.descricao,
    required this.sheets,
    required this.abas,
    this.limiteConhecido = false,
  });

  /// Nome do arquivo (sem extensão).
  final String slug;
  final String descricao;
  final Map<String, List<WCell>> sheets;

  /// aba -> verdade esperada (ver [_expected]).
  final Map<String, Map<String, Object?>> abas;

  /// O leitor determinístico **não** dá conta deste layout (ex.: ordem de
  /// colunas diferente). Vale para documentar o limite: a localização ainda
  /// é conferida, mas contagens e totais não são exigidos.
  final bool limiteConhecido;

  Map<String, Object?> toJson() => {
    'descricao': descricao,
    'limiteConhecido': limiteConhecido,
    'abas': abas,
  };
}

const _despesasHeader = ['Nome', 'Valor', 'Tipo', 'Banco', 'Observação', 'Dia'];
const _entradaHeader = ['Nome', 'Valor', 'Banco', 'Observação', 'Dia'];

void _header(List<WCell> cells, int row, int col, List<String> labels) {
  for (var i = 0; i < labels.length; i++) {
    cells.add(WCell(row, col + i, labels[i]));
  }
}

void _despesas(List<WCell> cells, int headerRow, int col, List<Despesa> rows, {List<String> header = _despesasHeader}) {
  _header(cells, headerRow, col, header);
  for (var i = 0; i < rows.length; i++) {
    final r = headerRow + 1 + i;
    final d = rows[i];
    // Cada rótulo do cabeçalho diz em que coluna vai o seu valor — assim uma
    // ordem trocada (layout "colunas-trocadas") sai coerente com o cabeçalho.
    final values = <String, Object?>{
      'Nome': d.nome,
      'Valor': d.valor,
      'Tipo': d.tipo,
      'Banco': d.banco,
      'Observação': d.obs,
      'Dia': d.dia,
    };
    for (var c = 0; c < header.length; c++) {
      final v = values[header[c]];
      if (v != null) cells.add(WCell(r, col + c, v));
    }
  }
}

void _entradas(List<WCell> cells, int headerRow, int col, List<Entrada> rows) {
  _header(cells, headerRow, col, _entradaHeader);
  for (var i = 0; i < rows.length; i++) {
    final r = headerRow + 1 + i;
    final e = rows[i];
    cells.add(WCell(r, col, e.nome));
    cells.add(WCell(r, col + 1, e.valor));
    cells.add(WCell(r, col + 2, e.banco));
    if (e.obs != null) cells.add(WCell(r, col + 3, e.obs!));
    if (e.dia != null) cells.add(WCell(r, col + 4, e.dia!));
  }
}

int _cents(double v) => (v * 100).round();

/// Verdade esperada de uma aba, **calculada a partir das linhas gravadas** —
/// nenhum número é digitado à mão, então o gerador e o teste não podem
/// divergir por erro de conta.
Map<String, Object?> _expected({
  required int despesasHeaderRow,
  required int despesasCol,
  required int entradaHeaderRow,
  required int entradaCol,
  required List<Despesa> despesas,
  required List<Entrada> entradas,
}) {
  bool isNome(String nome, String alvo) => nome.trim().toLowerCase() == alvo;
  final soDespesas = despesas.where((d) => !isNome(d.nome, 'fatura') && !isNome(d.nome, 'transfer'));
  final faturas = despesas.where((d) => isNome(d.nome, 'fatura'));
  final transfers = despesas.where((d) => isNome(d.nome, 'transfer'));
  final soEntradas = entradas.where((e) => !isNome(e.nome, 'transfer'));
  final espelhos = entradas.where((e) => isNome(e.nome, 'transfer'));
  int sum(Iterable<double> v) => v.fold(0, (a, b) => a + _cents(b));

  return {
    'despesasGerais': {'headerRow': despesasHeaderRow, 'startCol': despesasCol},
    'entradaDeValor': {'headerRow': entradaHeaderRow, 'startCol': entradaCol},
    'contagens': {
      'despesas': soDespesas.length,
      'entradas': soEntradas.length,
      'transfers': transfers.length,
      'billPayments': faturas.length,
      'mirrorsConsumed': espelhos.length,
      'rowErrors': 0,
    },
    'totaisCents': {
      'despesas': sum(soDespesas.map((d) => d.valor)),
      'entradas': sum(soEntradas.map((e) => e.valor)),
      'transfers': sum(transfers.map((d) => d.valor)),
      'billPayments': sum(faturas.map((d) => d.valor)),
    },
  };
}

DateTime _d(int m, int d) => DateTime(2026, m, d);

/// Todos os modelos que o gerador grava em `docs/exemplo/`.
///
/// **Dados inventados.** Contas "Azul" e "Verde", cartão "Roxo" — nada daqui
/// vem de planilha real. Para acrescentar um modelo: crie outra função e
/// inclua na lista (ver `docs/exemplo/LEIAME.md`).
List<GeneratedCase> allCases() => [
  _espelhoDoReal(),
  _deslocado(),
  _empilhado(),
  _colunasTrocadas(),
  _armadilhasDoReal(),
];

// --- (e) armadilhas achadas na planilha real (feat 0025) ----------------------

/// Data serial do Excel, gravada como NÚMERO comum (sem formato de data).
double _serial(DateTime d) => d.difference(DateTime(1899, 12, 30)).inDays.toDouble();

/// Os traços que fizeram a importação da planilha real trazer ~50 de ~70 linhas,
/// com dados inventados: linhas sem data no fim da tabela, parcelas com a data
/// da compra original (formato "4/10" e o formato antigo, Observação = data da
/// última parcela como número), faturas sem o cartão na Observação e uma
/// transferência com espelho. Todas precisam virar lançamento, sem erro.
GeneratedCase _armadilhasDoReal() {
  final despesas = [
    Despesa('Padaria', 12.5, 'Debito', 'Azul', dia: _d(9, 2)),
    Despesa('Mercado', 230.9, 'Debito', 'Verde', dia: _d(9, 10)),
    Despesa('Cinema', 55, 'Crédito', 'Roxo', dia: _d(9, 18)),
    Despesa('Farmácia', 67.8, 'Debito', 'Azul', dia: _d(9, 24)),
    // Parcelas com a data da compra original, meses antes.
    Despesa('Geladeira', 250, 'Crédito', 'Roxo', obs: '4/10', dia: _d(6, 12)),
    Despesa('Sofá', 180, 'Crédito', 'Roxo', obs: '2 / 6', dia: _d(8, 5)),
    Despesa('TV', 200, 'Crédito', 'Roxo', obs: _serial(_d(12, 20)), dia: _d(3, 20)),
    // Faturas: uma com o cartão, uma sem (Observação vazia).
    Despesa('fatura', 300, 'Debito', 'Azul', obs: 'Roxo', dia: _d(9, 10)),
    Despesa('fatura', 150, 'Debito', 'Verde', dia: _d(9, 11)),
    Despesa('transfer', 400, 'Debito', 'Azul', obs: 'Verde', dia: _d(9, 15)),
    // Sem data, no fim da tabela.
    Despesa('Feira', 42, 'Debito', 'Azul'),
    Despesa('Assinatura', 29.9, 'Crédito', 'Roxo'),
    Despesa('fatura', 90, 'Debito', 'Azul', obs: 'Roxo'),
  ];
  final entradas = [
    Entrada('Salario', 5000, 'Azul', dia: _d(9, 5)),
    Entrada('transfer', 400, 'Verde', obs: 'Azul', dia: _d(9, 15)),
    Entrada('Reembolso', 60, 'Verde'), // sem data
  ];
  final c = <WCell>[];
  _despesas(c, 18, 1, despesas);
  _despesas(c, 18, 8, const [Despesa('Internet', 99.9, 'Debito', 'Azul')]); // Recorrentes
  _entradas(c, 18, 15, entradas);
  return GeneratedCase(
    slug: 'armadilhas-do-real',
    descricao:
        'Traços da planilha real com dados inventados: linhas sem data no fim, parcelas com a '
        'data da compra (texto "4/10" e formato antigo com a data da última parcela como número), '
        'fatura sem o cartão e transferência com espelho. Tudo vira lançamento, sem erro.',
    sheets: {'Setembro': c},
    abas: {
      'Setembro': _expected(
        despesasHeaderRow: 18,
        despesasCol: 1,
        entradaHeaderRow: 18,
        entradaCol: 15,
        despesas: despesas,
        entradas: entradas,
      ),
    },
  );
}

// --- (a) espelho do layout real -----------------------------------------------

/// O mesmo esqueleto da planilha real: blocos no topo, a tabela de **Faturas**
/// (que também começa com "Nome") antes de Despesas Gerais, Gastos Recorrentes
/// (mesmo cabeçalho de Despesas Gerais) no meio e Entrada de Valor à direita.
/// Traz as três armadilhas de transferência: destino preenchido, destino em
/// branco (completado pelo espelho) e espelho sem data.
GeneratedCase _espelhoDoReal() {
  final mes1Despesas = [
    Despesa('Padaria', 12.5, 'Debito', 'Azul', dia: _d(1, 3)),
    Despesa('Mercado', 230.9, 'Debito', 'Verde', dia: _d(1, 4)),
    Despesa('Streaming', 39.9, 'Crédito', 'Roxo', obs: '1/1', dia: _d(1, 5)),
    Despesa('Livro', 45, 'Crédito', 'Roxo', dia: _d(1, 6)),
    Despesa('fatura', 300, 'Debito', 'Azul', obs: 'Roxo', dia: _d(1, 7)),
    Despesa('transfer', 500, 'Debito', 'Azul', obs: 'Verde', dia: _d(1, 8)),
    Despesa('transfer', 50, 'Debito', 'Verde', dia: _d(1, 9)), // destino em branco
  ];
  final mes1Entradas = [
    Entrada('Salario', 5000, 'Azul', dia: _d(1, 5)),
    Entrada('transfer', 500, 'Verde', obs: 'Azul', dia: _d(1, 8)),
    Entrada('transfer', 50, 'Azul'), // espelho sem data
    Entrada('Freela', 800, 'Verde', dia: _d(1, 15)),
  ];
  final mes2Despesas = [
    Despesa('Farmácia', 67.8, 'Debito', 'Azul', dia: _d(2, 2)),
    Despesa('Cinema', 55, 'Crédito', 'Roxo', dia: _d(2, 6)),
  ];
  final mes2Entradas = [Entrada('Salario', 5000, 'Azul', dia: _d(2, 5))];

  List<WCell> aba(List<Despesa> despesas, List<Entrada> entradas) {
    final c = <WCell>[
      const WCell(2, 1, 'Ganhos'),
      const WCell(2, 4, 'Bancos'),
      const WCell(2, 7, 'Total Mês'),
      const WCell(3, 1, 'Salario:'),
      const WCell(3, 2, 5000),
      const WCell(3, 4, 'Azul'),
      const WCell(3, 5, 1200.5),
      const WCell(4, 4, 'Verde'),
      const WCell(4, 5, 310.2),
    ];
    // Tabela de faturas: cabeçalho que também começa com "Nome".
    _header(c, 10, 1, ['Nome', 'Anterior', 'Atual', 'Vencimento', 'Até', 'Opção', 'Valor Pago', 'Restante']);
    c
      ..add(const WCell(11, 1, 'Roxo'))
      ..add(const WCell(11, 2, 0))
      ..add(const WCell(11, 3, 385.4))
      ..add(const WCell(11, 4, 10))
      ..add(const WCell(11, 5, 3))
      ..add(const WCell(11, 6, 'Pago'))
      ..add(const WCell(11, 7, 300))
      ..add(const WCell(11, 8, 85.4));
    _despesas(c, 18, 1, despesas);
    // Gastos Recorrentes: mesmo cabeçalho, mais à direita — deve ser ignorada.
    _despesas(c, 18, 8, const [Despesa('Internet', 99.9, 'Debito', 'Azul')]);
    _entradas(c, 18, 15, entradas);
    return c;
  }

  return GeneratedCase(
    slug: 'espelho-do-real',
    descricao:
        'Esqueleto da planilha real: tabela de Faturas antes de Despesas Gerais, '
        'Gastos Recorrentes no meio, Entrada de Valor à direita, e pares de '
        'transferência (com destino em branco e espelho sem data).',
    sheets: {'Mes1': aba(mes1Despesas, mes1Entradas), 'Mes2': aba(mes2Despesas, mes2Entradas)},
    abas: {
      'Mes1': _expected(
        despesasHeaderRow: 18,
        despesasCol: 1,
        entradaHeaderRow: 18,
        entradaCol: 15,
        despesas: mes1Despesas,
        entradas: mes1Entradas,
      ),
      'Mes2': _expected(
        despesasHeaderRow: 18,
        despesasCol: 1,
        entradaHeaderRow: 18,
        entradaCol: 15,
        despesas: mes2Despesas,
        entradas: mes2Entradas,
      ),
    },
  );
}

// --- (b) tabelas deslocadas, sem Faturas --------------------------------------

GeneratedCase _deslocado() {
  final despesas = [
    Despesa('Café', 8, 'Debito', 'Azul', dia: _d(3, 1)),
    Despesa('Combustível', 180, 'Crédito', 'Roxo', dia: _d(3, 2)),
  ];
  final entradas = [Entrada('Salario', 4200, 'Azul', dia: _d(3, 5))];
  final c = <WCell>[const WCell(1, 0, 'Controle do mês')];
  _despesas(c, 3, 0, despesas);
  _entradas(c, 3, 7, entradas);
  return GeneratedCase(
    slug: 'deslocado',
    descricao: 'Sem tabela de Faturas nem Recorrentes; cabeçalho na linha 3, Despesas na coluna A.',
    sheets: {'Dados': c},
    abas: {
      'Dados': _expected(
        despesasHeaderRow: 3,
        despesasCol: 0,
        entradaHeaderRow: 3,
        entradaCol: 7,
        despesas: despesas,
        entradas: entradas,
      ),
    },
  );
}

// --- (c) tabelas empilhadas na vertical ---------------------------------------

GeneratedCase _empilhado() {
  final despesas = [
    Despesa('Aluguel', 1200, 'Debito', 'Azul', dia: _d(4, 1)),
    Despesa('Luz', 140.3, 'Debito', 'Azul', dia: _d(4, 8)),
    Despesa('fatura', 220, 'Debito', 'Azul', obs: 'Roxo', dia: _d(4, 9)),
  ];
  final entradas = [
    Entrada('Salario', 4200, 'Azul', dia: _d(4, 5)),
    Entrada('Reembolso', 90, 'Verde', dia: _d(4, 12)),
  ];
  final c = <WCell>[];
  _despesas(c, 2, 0, despesas);
  // "Recorrentes" à direita de Despesas (mesmo cabeçalho): a regra é "a mais à esquerda".
  _despesas(c, 2, 8, const [Despesa('Academia', 90, 'Debito', 'Azul')]);
  // Entrada de Valor **abaixo**, e não ao lado.
  _entradas(c, 12, 0, entradas);
  return GeneratedCase(
    slug: 'empilhado',
    descricao: 'Entrada de Valor abaixo de Despesas Gerais (não ao lado), com Recorrentes à direita.',
    sheets: {'Tudo': c},
    abas: {
      'Tudo': _expected(
        despesasHeaderRow: 2,
        despesasCol: 0,
        entradaHeaderRow: 12,
        entradaCol: 0,
        despesas: despesas,
        entradas: entradas,
      ),
    },
  );
}

// --- (d) colunas em outra ordem: LIMITE CONHECIDO -----------------------------

/// A IA acha a tabela, mas o leitor determinístico assume a ordem
/// Nome|Valor|Tipo|Banco|Observação|Dia — aqui a ordem é outra, e o resultado
/// sai errado. Está no corpus **para documentar o limite**, não para passar.
GeneratedCase _colunasTrocadas() {
  final despesas = [
    Despesa('Padaria', 12.5, 'Debito', 'Azul', dia: _d(5, 3)),
    Despesa('Mercado', 230.9, 'Debito', 'Verde', dia: _d(5, 4)),
  ];
  final entradas = [Entrada('Salario', 4200, 'Azul', dia: _d(5, 5))];
  final c = <WCell>[];
  _despesas(c, 2, 0, despesas, header: const ['Nome', 'Banco', 'Valor', 'Tipo', 'Dia', 'Observação']);
  _entradas(c, 2, 8, entradas);
  return GeneratedCase(
    slug: 'colunas-trocadas',
    descricao: 'LIMITE CONHECIDO: Despesas Gerais com as colunas em outra ordem (Nome, Banco, Valor, Tipo, Dia, Observação).',
    limiteConhecido: true,
    sheets: {'Dados': c},
    abas: {
      'Dados': _expected(
        despesasHeaderRow: 2,
        despesasCol: 0,
        entradaHeaderRow: 2,
        entradaCol: 8,
        despesas: despesas,
        entradas: entradas,
      ),
    },
  );
}
