import '../../../core/utils/formatters.dart';
import 'entry_type.dart';

// Regras de negócio do dinheiro no formulário de lançamento: uma conta não
// transfere o que não tem, e uma fatura não recebe mais do que deve.
//
// **Só o formulário manual usa isto.** A importação de planilha grava o
// histórico sem os saldos iniciais (as faturas da aba mais antiga pagam compras
// de meses que ainda não estão no banco), então uma checagem no repositório
// rejeitaria linhas legítimas.

/// Motivo de a transferência não poder ser feita, ou `null` se pode.
///
/// [availableCents] é o saldo da conta de origem na data da transferência,
/// **já sem o lançamento que está sendo editado** (ver [balanceEffect]).
/// Cheque especial não é tratado: quem está no negativo não transfere.
String? transferBlockedReason({
  required String accountName,
  required int availableCents,
  required int amountCents,
}) {
  if (amountCents <= availableCents) return null;
  return 'Saldo insuficiente: $accountName tem ${Formatters.money(availableCents)}.';
}

/// Motivo de o pagamento não poder ser feito, ou `null` se pode.
///
/// [openCents] é quanto está em aberto no cartão na data do pagamento (positivo
/// = deve), já sem o lançamento que está sendo editado. Pagar **menos** que o
/// em aberto é permitido: é o pagamento parcial.
///
/// [interestCents] são os juros e encargos que o banco cobrou nesta fatura e o
/// app ainda não tinha (juros, multa, IOF, anuidade). Eles viram um gasto no
/// cartão junto com o pagamento, então a fatura pode ir até o em aberto **mais**
/// esse valor.
String? billPaymentBlockedReason({
  required String cardName,
  required int openCents,
  required int amountCents,
  int interestCents = 0,
}) {
  final payable = openCents + interestCents;
  if (payable <= 0) return 'Não há fatura em aberto em $cardName.';
  if (amountCents <= payable) return null;
  // Cartão com crédito (em aberto negativo: pagamentos de fatura que superam as
  // compras registradas): dizer "tem -R$ x em aberto" confunde. Fala só do que
  // dá para pagar.
  if (openCents <= 0) {
    return 'Acima do que dá para pagar em $cardName: '
        '${Formatters.money(payable)} (o crédito do cartão abate os juros e '
        'encargos informados).';
  }
  final extra = interestCents > 0
      ? ' mais ${Formatters.money(interestCents)} de juros e encargos'
      : '';
  return 'Acima do que está em aberto: $cardName tem '
      '${Formatters.money(openCents)} em aberto$extra.';
}

/// O que sobra no cartão depois de um pagamento de fatura.
class BillPaymentOutcome {
  const BillPaymentOutcome(this.openAfterCents);

  /// Quanto continua em aberto (nunca negativo: o que passa disso é recusado
  /// por [billPaymentBlockedReason]).
  final int openAfterCents;

  /// A fatura ficou quitada.
  bool get isSettled => openAfterCents <= 0;
}

/// Em aberto depois de pagar: o que já estava, mais os juros e encargos que
/// entram agora, menos o valor pago. Pagar menos que a fatura deixa a diferença
/// no cartão, que é o que o banco também faz (ela entra na próxima fatura).
BillPaymentOutcome billPaymentOutcome({
  required int openCents,
  required int paidCents,
  int interestCents = 0,
}) => BillPaymentOutcome(openCents + interestCents - paidCents);

/// Quanto um lançamento soma (ou tira) do saldo da conta [forAccountId].
///
/// Espelha a fórmula de `EntriesRepository.watchBalances`. Serve para
/// **desfazer** o efeito do lançamento que está sendo editado antes de checar
/// o saldo: sem isso, editar uma transferência de R$ 50 numa conta que ficou
/// com R$ 50 a bloquearia por "falta de saldo" que ela mesma consumiu.
int balanceEffect({
  required EntryType type,
  required int amountCents,
  required int accountId,
  int? toAccountId,
  required int forAccountId,
}) {
  var effect = 0;
  if (accountId == forAccountId) {
    effect += switch (type) {
      EntryType.income || EntryType.adjustmentIncrease => amountCents,
      EntryType.expense ||
      EntryType.adjustmentDecrease ||
      EntryType.transfer ||
      EntryType.billPayment => -amountCents,
    };
  }
  if (toAccountId == forAccountId && type.hasDestination) effect += amountCents;
  return effect;
}
