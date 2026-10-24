import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../data/entries_repository.dart';
import '../domain/entry_type.dart';
import '../domain/payment_rules.dart';

/// As regras de dinheiro da transferência e do pagamento de fatura (ver
/// `payment_rules.dart`). Vale **só no formulário**: a importação grava
/// histórico sem os saldos iniciais e não pode ser barrada por elas.
///
/// Confere o saldo **na data do lançamento** e, ao editar, sem o efeito do
/// próprio lançamento ([original]; senão a transferência bloquearia a si mesma).
Future<String?> entryMoneyRuleReason({
  required EntriesRepository repo,
  required EntryType type,
  required DateTime date,
  required Entry? original,
  required Account account,
  required Account? toAccount,
  required int cents,
  required int interestCents,
}) async {
  if (type != EntryType.transfer && type != EntryType.billPayment) {
    return null;
  }
  Future<int> balanceWithoutThisEntry(int accountId) async {
    var balance = await repo.balanceOf(accountId, today: date);
    if (original != null &&
        !DateUtils.dateOnly(original.date).isAfter(DateUtils.dateOnly(date))) {
      balance -= balanceEffect(
        type: original.type,
        amountCents: original.amountCents,
        accountId: original.accountId,
        toAccountId: original.toAccountId,
        forAccountId: accountId,
      );
    }
    return balance;
  }

  if (type == EntryType.transfer) {
    return transferBlockedReason(
      accountName: account.name,
      availableCents: await balanceWithoutThisEntry(account.id),
      amountCents: cents,
    );
  }
  return billPaymentBlockedReason(
    cardName: toAccount!.name,
    // No cartão o saldo é negativo quando há fatura: em aberto = -saldo.
    openCents: -(await balanceWithoutThisEntry(toAccount.id)),
    amountCents: cents,
    interestCents: interestCents,
  );
}
