import 'layouts.dart';
import 'xlsx_writer.dart';

/// Planilhas **diferentes** do layout em que o importador foi desenhado (feat
/// 0044). Servem para medir, com a IA de verdade e com o leitor, o que o app lê
/// e o que não lê quando a planilha de outra pessoa tem outra forma.
///
/// Dados inventados (contas "Azul" e "Verde", cartão "Roxo"). Duas famílias:
///
/// * **Mesma forma, outros rótulos** (`ingles`, `sinonimos`): o layout é o do app,
///   só os cabeçalhos mudam. Se a IA reconhecer, o caso é suportado.
/// * **Outra forma** (os demais): `limiteConhecido`. Onde não existem as duas
///   tabelas do app, a resposta certa da IA é "não achei" (localização `null`) e o
///   app deve dizer isso com clareza; onde existem mas com outra estrutura
///   (`colunas-extras`, `data-completa-texto`), o leitor falha de um modo que o
///   teste documenta.
List<GeneratedCase> extraCases() => [
  _comRotulos(
    slug: 'ingles',
    descricao: 'Layout do app com cabeçalhos em inglês (Name, Amount, Type, Bank, Note, Day).',
    despesasHeader: const ['Name', 'Amount', 'Type', 'Bank', 'Note', 'Day'],
    entradaHeader: const ['Name', 'Amount', 'Bank', 'Note', 'Day'],
  ),
  _comRotulos(
    slug: 'sinonimos',
    descricao: 'Layout do app com outros nomes de coluna (Descrição, Quanto, Forma, Conta, Obs, Data).',
    despesasHeader: const [
      'Descrição',
      'Quanto',
      'Forma',
      'Conta',
      'Obs',
      'Data',
    ],
    entradaHeader: const ['Descrição', 'Quanto', 'Conta', 'Obs', 'Data'],
  ),
  _colunasExtras(),
  _dataEmTexto(),
  _valorComSinal(),
  _extratoDeBanco(),
  _mesEmColunas(),
  _abasPorBanco(),
  _soGastosSimples(),
];

DateTime _d(int m, int d) => DateTime(2026, m, d);

final _despesas = [
  Despesa('Padaria', 12.5, 'Debito', 'Azul', dia: _d(10, 3)),
  Despesa('Mercado', 230.9, 'Debito', 'Verde', dia: _d(10, 4)),
  Despesa('Streaming', 39.9, 'Crédito', 'Roxo', obs: '1/1', dia: _d(10, 5)),
  Despesa('Livro', 45, 'Crédito', 'Roxo', dia: _d(10, 6)),
  Despesa('fatura', 300, 'Debito', 'Azul', obs: 'Roxo', dia: _d(10, 7)),
];
final _entradas = [
  Entrada('Salario', 5000, 'Azul', dia: _d(10, 5)),
  Entrada('Freela', 800, 'Verde', dia: _d(10, 15)),
];

const _headerRow = 3;
const _despesasCol = 1;
const _entradaCol = 9;

Map<String, Object?> _expectedLayoutDoApp() => expectedSheet(
  despesasHeaderRow: _headerRow,
  despesasCol: _despesasCol,
  entradaHeaderRow: _headerRow,
  entradaCol: _entradaCol,
  despesas: _despesas,
  entradas: _entradas,
);

/// Verdade para uma planilha que **não tem** as duas tabelas do app.
Map<String, Object?> get _semTabelas => {
  'despesasGerais': null,
  'entradaDeValor': null,
  'contagens': <String, Object?>{},
  'totaisCents': <String, Object?>{},
};

/// Escreve uma tabela com os rótulos dados e os valores na ordem canônica do app.
void _tabela(
  List<WCell> c,
  int row,
  int col,
  List<String> header,
  List<List<Object?>> linhas,
) {
  for (var i = 0; i < header.length; i++) {
    c.add(WCell(row, col + i, header[i]));
  }
  for (var r = 0; r < linhas.length; r++) {
    for (var i = 0; i < linhas[r].length; i++) {
      final v = linhas[r][i];
      if (v != null) c.add(WCell(row + 1 + r, col + i, v));
    }
  }
}

List<List<Object?>> _linhasDespesas() => [
  for (final d in _despesas) [d.nome, d.valor, d.tipo, d.banco, d.obs, d.dia],
];
List<List<Object?>> _linhasEntradas() => [
  for (final e in _entradas) [e.nome, e.valor, e.banco, e.obs, e.dia],
];

GeneratedCase _comRotulos({
  required String slug,
  required String descricao,
  required List<String> despesasHeader,
  required List<String> entradaHeader,
}) {
  final c = <WCell>[];
  _tabela(c, _headerRow, _despesasCol, despesasHeader, _linhasDespesas());
  _tabela(c, _headerRow, _entradaCol, entradaHeader, _linhasEntradas());
  return GeneratedCase(
    slug: slug,
    descricao: descricao,
    sheets: {'Outubro': c},
    abas: {'Outubro': _expectedLayoutDoApp()},
  );
}

/// Uma coluna "Categoria" no meio das seis: o leitor lê por posição e desloca tudo.
GeneratedCase _colunasExtras() {
  final c = <WCell>[];
  _tabela(
    c,
    _headerRow,
    _despesasCol,
    const ['Nome', 'Valor', 'Categoria', 'Tipo', 'Banco', 'Observação', 'Dia'],
    [
      for (final d in _despesas)
        [d.nome, d.valor, 'Casa', d.tipo, d.banco, d.obs, d.dia],
    ],
  );
  _tabela(
    c,
    _headerRow,
    _entradaCol + 1,
    const ['Nome', 'Valor', 'Categoria', 'Banco', 'Observação', 'Dia'],
    [
      for (final e in _entradas)
        [e.nome, e.valor, 'Renda', e.banco, e.obs, e.dia],
    ],
  );
  final esperado = _expectedLayoutDoApp();
  esperado['entradaDeValor'] = {
    'headerRow': _headerRow,
    'startCol': _entradaCol + 1,
  };
  return GeneratedCase(
    slug: 'colunas-extras',
    descricao:
        'Layout do app com uma coluna "Categoria" no meio. As tabelas são achadas, mas o leitor '
        'assume as colunas em posições fixas e desloca os valores: limite conhecido.',
    sheets: {'Outubro': c},
    abas: {'Outubro': esperado},
    limiteConhecido: true,
  );
}

/// O dia escrito como texto ("05/10/2026") em vez de data.
GeneratedCase _dataEmTexto() {
  String txt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  final c = <WCell>[];
  _tabela(
    c,
    _headerRow,
    _despesasCol,
    const ['Nome', 'Valor', 'Tipo', 'Banco', 'Observação', 'Dia'],
    [
      for (final d in _despesas)
        [d.nome, d.valor, d.tipo, d.banco, d.obs, txt(d.dia!)],
    ],
  );
  _tabela(
    c,
    _headerRow,
    _entradaCol,
    const ['Nome', 'Valor', 'Banco', 'Observação', 'Dia'],
    [
      for (final e in _entradas) [e.nome, e.valor, e.banco, e.obs, txt(e.dia!)],
    ],
  );
  return GeneratedCase(
    slug: 'data-em-texto',
    descricao:
        'Layout do app, mas o dia vem como texto ("05/10/2026"). O leitor só aceita célula de data '
        'ou número de data: limite conhecido.',
    sheets: {'Outubro': c},
    abas: {'Outubro': _expectedLayoutDoApp()},
    limiteConhecido: true,
  );
}

/// Uma tabela só, com o sinal do valor dizendo se é gasto (−) ou entrada (+).
GeneratedCase _valorComSinal() {
  final c = <WCell>[];
  _tabela(
    c,
    2,
    1,
    const ['Data', 'Descrição', 'Valor', 'Conta'],
    [
      [_d(10, 3), 'Padaria', -12.5, 'Azul'],
      [_d(10, 4), 'Mercado', -230.9, 'Verde'],
      [_d(10, 5), 'Salario', 5000, 'Azul'],
      [_d(10, 15), 'Freela', 800, 'Verde'],
    ],
  );
  return GeneratedCase(
    slug: 'valor-com-sinal',
    descricao: 'Uma tabela só (Data, Descrição, Valor, Conta); gasto é negativo e entrada é positiva.',
    sheets: {'Outubro': c},
    abas: {'Outubro': _semTabelas},
    limiteConhecido: true,
  );
}

/// Extrato de banco: débito e crédito em colunas separadas, com saldo.
GeneratedCase _extratoDeBanco() {
  final c = <WCell>[];
  _tabela(
    c,
    2,
    1,
    const ['Data', 'Histórico', 'Débito', 'Crédito', 'Saldo'],
    [
      [_d(10, 3), 'COMPRA PADARIA', 12.5, null, 987.5],
      [_d(10, 4), 'COMPRA MERCADO', 230.9, null, 756.6],
      [_d(10, 5), 'SALARIO', null, 5000, 5756.6],
      [_d(10, 15), 'PIX RECEBIDO', null, 800, 6556.6],
    ],
  );
  return GeneratedCase(
    slug: 'extrato-banco',
    descricao: 'Extrato de banco: Data, Histórico, Débito, Crédito e Saldo, com débito e crédito em colunas separadas.',
    sheets: {'Outubro': c},
    abas: {'Outubro': _semTabelas},
    limiteConhecido: true,
  );
}

/// Categorias nas linhas e um mês por coluna (a planilha "do ano inteiro").
GeneratedCase _mesEmColunas() {
  final c = <WCell>[];
  _tabela(
    c,
    2,
    1,
    const ['Categoria', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun'],
    [
      ['Moradia', 1200, 1200, 1200, 1200, 1200, 1200],
      ['Mercado', 650.4, 702.1, 598, 640, 710.3, 688],
      ['Transporte', 180, 175.5, 190, 160, 185, 170],
      ['Lazer', 220, 90, 310, 150, 80, 260],
    ],
  );
  return GeneratedCase(
    slug: 'mes-em-colunas',
    descricao: 'Planilha do ano: categorias nas linhas e um mês por coluna, sem datas nem bancos por lançamento.',
    sheets: {'Ano': c},
    abas: {'Ano': _semTabelas},
    limiteConhecido: true,
  );
}

/// Uma aba por banco, cada uma com Data, Descrição e Valor.
GeneratedCase _abasPorBanco() {
  List<WCell> aba(List<List<Object?>> linhas) {
    final c = <WCell>[];
    _tabela(c, 1, 0, const ['Data', 'Descrição', 'Valor'], linhas);
    return c;
  }

  return GeneratedCase(
    slug: 'abas-por-banco',
    descricao: 'Uma aba por banco (Azul, Verde), cada uma com Data, Descrição e Valor; o banco é o nome da aba.',
    sheets: {
      'Azul': aba([
        [_d(10, 3), 'Padaria', 12.5],
        [_d(10, 7), 'Streaming', 39.9],
      ]),
      'Verde': aba([
        [_d(10, 4), 'Mercado', 230.9],
        [_d(10, 9), 'Farmácia', 67.8],
      ]),
    },
    abas: {'Azul': _semTabelas, 'Verde': _semTabelas},
    limiteConhecido: true,
  );
}

/// Só gastos, numa tabela simples com categoria e sem banco nem tipo.
GeneratedCase _soGastosSimples() {
  final c = <WCell>[];
  _tabela(
    c,
    1,
    0,
    const ['Data', 'Descrição', 'Valor', 'Categoria'],
    [
      [_d(10, 3), 'Padaria', 12.5, 'Alimentação'],
      [_d(10, 4), 'Mercado', 230.9, 'Alimentação'],
      [_d(10, 6), 'Livro', 45, 'Lazer'],
      [_d(10, 8), 'Ônibus', 18, 'Transporte'],
    ],
  );
  return GeneratedCase(
    slug: 'so-gastos-simples',
    descricao: 'Só gastos: Data, Descrição, Valor e Categoria numa tabela, sem banco, tipo nem entradas.',
    sheets: {'Outubro': c},
    abas: {'Outubro': _semTabelas},
    limiteConhecido: true,
  );
}
