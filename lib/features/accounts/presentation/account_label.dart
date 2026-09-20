import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// "Bradesco" ou "Bradesco · cartão" — conta e cartão da mesma instituição
/// costumam ter o mesmo nome, então o tipo desempata.
///
/// Com [all] (a lista de contas), o cartão mostra também a conta dona:
/// "Amazon · cartão do Bradesco".
String accountLabel(Account account, {List<Account>? all}) {
  if (!account.kind.isCard) return account.name;
  final owner = ownerOf(account, all);
  return owner == null
      ? '${account.name} · cartão'
      : '${account.name} · cartão do ${owner.name}';
}

/// A conta dona de um cartão, se estiver vinculada e presente em [all].
Account? ownerOf(Account card, List<Account>? all) {
  final ownerId = card.linkedAccountId;
  if (ownerId == null || all == null) return null;
  return all.where((a) => a.id == ownerId).firstOrNull;
}

/// Título do cartão nos totais e saldos: "Cartão Amazon". Sem repetir quando
/// o próprio nome já diz ("Cartão Bradesco" não vira "Cartão Cartão Bradesco").
String cardTitle(Account card) {
  final name = card.name;
  final normalized = name.toLowerCase().replaceAll('ã', 'a');
  return normalized.startsWith('cartao') ? name : 'Cartão $name';
}

IconData accountIcon(Account account) =>
    account.kind.isCard ? Icons.credit_card : Icons.account_balance_outlined;
