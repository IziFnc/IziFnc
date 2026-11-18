import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories.dart';
import '../../../core/utils/cents_input_formatter.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../../accounts/presentation/account_label.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../data/entries_repository.dart';
import '../domain/entry_type.dart';
import 'bill_payment_summary.dart';
import 'entry_account_chips.dart';
import 'entry_amount_field.dart';
import 'entry_form_logic.dart';
import 'entry_money_rule.dart';
import 'entry_persistence.dart';

/// Botão "Pagar fatura" da tela de um cartão (abre [BillPaymentScreen]).
class PayBillButton extends StatelessWidget {
  const PayBillButton({super.key, required this.cardId, this.enabled = true});

  final int cardId;

  /// Desligado enquanto há alterações sem salvar na tela do cartão (um ajuste de saldo
  /// pendente seria calculado depois do pagamento e o desfaria).
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: FilledButton.tonalIcon(
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Pagar fatura'),
        onPressed: enabled ? () => context.push(BillPaymentScreen.pathFor(cardId)) : null,
      ),
    ),
  );
}

/// Pagar a fatura de um cartão (feat 0042): tela própria, aberta a partir do
/// cartão, com o valor em aberto já preenchido. Mesma regra e mesmo tipo
/// ([EntryType.billPayment]) do formulário de lançamento, que agora só **edita**
/// pagamentos antigos.
class BillPaymentScreen extends ConsumerStatefulWidget {
  const BillPaymentScreen({super.key, required this.cardId});

  static const String pattern = '/cartoes/:id/pagar';
  static String pathFor(int cardId) => '/cartoes/$cardId/pagar';

  final int cardId;

  @override
  ConsumerState<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends ConsumerState<BillPaymentScreen> {
  final _amount = TextEditingController();
  final _interest = TextEditingController();
  final _amountFocus = FocusNode();
  late DateTime _date = DateUtils.dateOnly(ref.read(clockProvider)());
  int? _fromId;
  bool _filled = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _interest.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  int get _interestCents => CentsInputFormatter.parse(_interest.text);

  Future<void> _pickDate() async {
    final picked = await pickEntryDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pay(Account card, Account from) async {
    final cents = CentsInputFormatter.parse(_amount.text);
    if (cents == 0) {
      setState(() => _error = 'Informe o valor que você vai pagar.');
      return;
    }
    if (_saving) return;
    final repo = ref.read(entriesRepositoryProvider);
    // Trava já: dois toques seguidos passariam os dois pela checagem antes de gravar.
    setState(() {
      _saving = true;
      _error = null;
    });
    final blocked = await entryMoneyRuleReason(
      repo: repo,
      type: EntryType.billPayment,
      date: _date,
      original: null,
      account: from,
      toAccount: card,
      cents: cents,
      interestCents: _interestCents,
    );
    if (blocked != null) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = blocked;
        });
      }
      return;
    }
    try {
      await saveEntryWithInterest(
        repo,
        EntryDraft(
          accountId: from.id,
          toAccountId: card.id,
          type: EntryType.billPayment,
          description: 'Pagamento fatura ${card.name}',
          amountCents: cents,
          date: _date,
        ),
        interestCents: _interestCents,
        cardId: card.id,
      );
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Não foi possível pagar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value;
    final balances = ref.watch(accountBalancesProvider).value;
    if (accounts == null || balances == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagar fatura')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final card = accounts.where((a) => a.id == widget.cardId && a.kind.isCard).firstOrNull;
    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagar fatura')),
        body: const Center(child: Text('Cartão não encontrado.')),
      );
    }

    final checking = accounts.where((a) => !a.kind.isCard).toList();
    final open = -(balances[card.id] ?? 0);

    // Valor já preenchido com o em aberto (uma vez), e a conta dona já escolhida.
    if (!_filled) {
      _filled = true;
      _fromId = card.linkedAccountId ?? (checking.length == 1 ? checking.first.id : null);
      if (open > 0) _amount.text = CentsInputFormatter.format(open);
    }
    final from = checking.where((a) => a.id == _fromId).firstOrNull;
    final paid = CentsInputFormatter.parse(_amount.text);
    final canPay = open + _interestCents > 0 && from != null && !_saving;

    return Scaffold(
      appBar: AppBar(title: Text('Pagar fatura · ${cardTitle(card)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Fatura em aberto', style: theme.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            open > 0 ? Formatters.money(open) : 'Nada em aberto',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (card.dueDay != null || card.closingDay != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (card.closingDay != null) 'fecha dia ${card.closingDay}',
                  if (card.dueDay != null) 'vence dia ${card.dueDay}',
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 20),
          if (open <= 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Não há fatura em aberto neste cartão. Se o banco cobrou juros, multa ou anuidade, '
                'informe abaixo para pagar.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ...[
            EntryAmountField(
              controller: _amount,
              focusNode: _amountFocus,
              autofocus: false,
              errorText: _error,
              onChanged: () => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            EntryAccountChips(
              label: 'Sai de',
              options: checking,
              allAccounts: accounts,
              selected: _fromId,
              onSelect: (id) => setState(() => _fromId = id),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _interest,
              keyboardType: TextInputType.number,
              inputFormatters: [CentsInputFormatter()],
              decoration: const InputDecoration(
                label: Text('Juros e encargos desta fatura (opcional)', maxLines: 2),
                hintText: 'R\$ 0,00',
                helperText:
                    'Se a fatura do banco veio maior que o em aberto no app, coloque aqui a '
                    'diferença (juros, multa, IOF). Ela vira um gasto no cartão.',
                helperMaxLines: 3,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            BillPaymentSummary(openCents: open, paidCents: paid, interestCents: _interestCents),
            const SizedBox(height: 8),
            Text(
              'Se você pagar menos, o que sobrar continua em aberto e o banco pode cobrar juros.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined),
              label: Text('Data: ${Formatters.date(_date)}'),
              onPressed: _pickDate,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: canPay ? () => _pay(card, from) : null,
              child: Text(paid > 0 ? 'Pagar ${Formatters.money(paid)}' : 'Pagar fatura'),
            ),
            if (from == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Escolha de qual conta sai o pagamento.', style: theme.textTheme.bodySmall),
              ),
          ],
        ],
      ),
    );
  }
}
