/// O que um lançamento é.
///
/// O valor é sempre gravado positivo; é o tipo que diz o que ele faz com o
/// saldo. Gravado como texto no banco (`textEnum`): **não renomear os valores**
/// sem migration, senão as linhas existentes deixam de ser lidas.
enum EntryType {
  expense,
  income,

  /// Dinheiro saindo de uma conta (`accountId`) e chegando em **outra conta**
  /// (`toAccountId`). Desde o schema v3, nunca em cartão — isso é [billPayment].
  transfer,

  /// Pagar a fatura: sai de uma conta (`accountId`) e abate o que está em
  /// aberto no cartão (`toAccountId`). Separado de [transfer] desde o schema v3
  /// para a intenção ficar explícita no dado (relatório, importação).
  billPayment,

  /// Correção de saldo para bater com o banco (ver "Ajustar saldo"). Dois tipos
  /// em vez de um valor com sinal: o banco exige valor > 0, e mudar isso
  /// obrigaria recriar a tabela na migração.
  adjustmentIncrease,
  adjustmentDecrease;

  String get label => switch (this) {
    expense => 'Despesa',
    income => 'Entrada',
    transfer => 'Transferência',
    billPayment => 'Pagar fatura',
    adjustmentIncrease || adjustmentDecrease => 'Ajuste de saldo',
  };

  /// Entra nos totais do mês (entradas, saídas no débito, cartões)?
  ///
  /// Transferência só move dinheiro entre contas suas, pagar a fatura não é
  /// gastar de novo (o gasto já contou no cartão), e ajuste só corrige o saldo.
  bool get affectsMonthTotals => this == expense || this == income;

  /// Tem conta de destino (`toAccountId`).
  bool get hasDestination => this == transfer || this == billPayment;

  bool get isAdjustment =>
      this == adjustmentIncrease || this == adjustmentDecrease;
}
