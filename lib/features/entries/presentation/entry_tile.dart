import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../accounts/presentation/account_label.dart';
import '../domain/entry_type.dart';
import '../domain/entry_with_account.dart';
import 'entry_form_screen.dart';

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.row});

  final EntryWithAccount row;

  @override
  Widget build(BuildContext context) {
    final EntryWithAccount(:entry, :account, :toAccount) = row;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final amount = Formatters.money(entry.amountCents);

    // Transferência "Bradesco → C6" e pagamento "Bradesco → fatura Amazon":
    // valor neutro (não é gasto). Ajuste: sinal explícito, também neutro.
    final (icon, where, shownAmount, color) = switch (entry.type) {
      EntryType.transfer => (
        Icons.swap_horiz,
        '${accountLabel(account)} → ${toAccount == null ? '?' : accountLabel(toAccount)}',
        amount,
        colors.onSurfaceVariant,
      ),
      EntryType.billPayment => (
        Icons.receipt_long_outlined,
        '${accountLabel(account)} → fatura ${toAccount?.name ?? '?'}',
        amount,
        colors.onSurfaceVariant,
      ),
      EntryType.adjustmentIncrease => (
        Icons.tune,
        accountLabel(account),
        '+ $amount',
        colors.onSurfaceVariant,
      ),
      EntryType.adjustmentDecrease => (
        Icons.tune,
        accountLabel(account),
        '− $amount',
        colors.onSurfaceVariant,
      ),
      EntryType.income => (
        accountIcon(account),
        accountLabel(account),
        '+ $amount',
        colors.primary,
      ),
      EntryType.expense => (
        accountIcon(account),
        accountLabel(account),
        amount,
        null,
      ),
    };

    return ListTile(
      leading: Icon(icon, color: colors.onSurfaceVariant),
      title: Text(entry.description),
      subtitle: Text(
        [Formatters.dayMonth(entry.date), where, ?entry.note].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // O valor é o que se procura na lista: no tamanho do texto do nome (o padrão
      // do trailing era ~11 sp) e em negrito leve.
      trailing: Text(
        shownAmount,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: () => context.push(EntryFormScreen.editPath(entry.id)),
    );
  }
}
