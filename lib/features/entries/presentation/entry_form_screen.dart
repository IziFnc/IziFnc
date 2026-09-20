import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories.dart';
import '../../../core/utils/cents_input_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/year_month.dart';
import '../../accounts/presentation/account_label.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../data/entries_repository.dart';
import '../domain/competence.dart';
import '../domain/entry_type.dart';
import '../domain/payment_rules.dart';
import 'month_providers.dart';

/// Criar ou editar um lançamento.
///
/// O valor vem primeiro e com foco: é o que se sabe na hora de lançar. Embaixo
/// fica o aviso `Vai para: dezembro de 2025`, para a regra de virada nunca ser
/// surpresa.
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({super.key, this.entryId});

  static const String newPath = '/lancamento/novo';
  static const String editPattern = '/lancamento/:id';
  static String editPath(int id) => '/lancamento/$id';

  final int? entryId;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();

  /// "Salvo: Café · R$ 10,00", depois de um "Salvar e novo"; some quando a
  /// pessoa começa o próximo valor.
  String? _lastSaved;
  final _description = TextEditingController();
  final _note = TextEditingController();

  /// Só em "Pagar fatura" novo: juros e encargos que o banco cobrou nesta
  /// fatura e o app ainda não tinha. Vazio = nenhum.
  final _interest = TextEditingController();

  EntryType _type = EntryType.expense;
  int? _accountId; // em transferência, a origem
  int? _toAccountId; // só em transferência
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  /// Ajuste de saldo aberto da lista: só dá para ver e excluir (ele nasce em
  /// "Ajustar saldo", não aqui).
  Entry? _adjustment;

  /// O lançamento como estava no banco, quando se está editando. As regras de
  /// saldo precisam desfazer o efeito dele antes de conferir o novo valor.
  Entry? _original;

  /// Motivo de o valor não poder ser salvo (saldo, fatura), e a situação em que
  /// ele foi dado. Ele só aparece enquanto a situação é a mesma: mudar valor,
  /// conta, tipo ou data já o esconde, sem precisar limpar em cada handler.
  String? _amountError;
  String? _amountErrorFor;

  bool _loading = false;
  bool _saving = false;
  bool _submitted = false; // só mostra erro de campo depois de tentar salvar

  /// A descrição da transferência é sugerida ("Pagamento fatura Amazon") até o
  /// usuário digitar nela; depois disso, a dele vale.
  bool _descriptionEdited = false;

  /// Os tipos que o formulário oferece. Ajuste fica de fora de propósito.
  static const _formTypes = [
    EntryType.expense,
    EntryType.income,
    EntryType.transfer,
    EntryType.billPayment,
  ];

  bool get _isEditing => widget.entryId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _load(widget.entryId!);
  }

  Future<void> _load(int id) async {
    setState(() => _loading = true);
    final entry = await ref.read(entriesRepositoryProvider).find(id);
    if (!mounted) return;
    if (entry == null) {
      context.pop(); // excluído em outro lugar
      return;
    }
    setState(() {
      _original = entry;
      _amount.text = CentsInputFormatter.format(entry.amountCents);
      _description.text = entry.description;
      _descriptionEdited = true;
      _note.text = entry.note ?? '';
      _type = entry.type;
      _accountId = entry.accountId;
      _toAccountId = entry.toAccountId;
      _date = entry.date;
      if (entry.type.isAdjustment) _adjustment = entry;
      _loading = false;
    });
  }

  /// Sugere a descrição da transferência, se o usuário ainda não escreveu a dele.
  /// Chamado nos eventos de seleção — nunca no build, onde mexer no controller
  /// dispararia "setState durante build".
  void _suggestDescription(List<Account> accounts) {
    if (_descriptionEdited) return;
    final to = accounts.where((a) => a.id == _toAccountId).firstOrNull;
    switch (_type) {
      case EntryType.transfer:
        _description.text = 'Transferência';
      case EntryType.billPayment:
        _description.text = to == null
            ? 'Pagamento fatura'
            : 'Pagamento fatura ${to.name}';
      default:
        _description.clear();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    _description.dispose();
    _note.dispose();
    _interest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final startDay = ref.watch(monthStartDayProvider).value;

    final hasDestination = _type.hasDestination;

    // Com uma conta só, não faz sentido obrigar a escolher.
    if (!_isEditing &&
        !hasDestination &&
        _accountId == null &&
        accounts.length == 1) {
      _accountId = accounts.single.id;
    }
    var account = accounts.where((a) => a.id == _accountId).firstOrNull;
    // Transferência e pagamento de fatura saem de conta: cartão como origem
    // não vale.
    if (hasDestination && account != null && account.kind.isCard) {
      account = null;
    }
    if (!hasDestination && account != null && account.kind.isCard) {
      _type = EntryType.expense;
    }

    // Transferência: outra conta. Pagar fatura: um cartão.
    final toAccount = switch (_type) {
      EntryType.transfer =>
        accounts
            .where(
              (a) =>
                  a.id == _toAccountId && !a.kind.isCard && a.id != account?.id,
            )
            .firstOrNull,
      EntryType.billPayment =>
        accounts
            .where((a) => a.id == _toAccountId && a.kind.isCard)
            .firstOrNull,
      _ => null,
    };

    // O mês segue a conta de origem, também na transferência e no pagamento.
    final competence = (account == null || startDay == null)
        ? null
        : _competence(account, startDay);

    final adjustment = _adjustment;
    if (adjustment != null) {
      return _adjustmentView(context, adjustment, accounts);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar lançamento' : 'Novo lançamento'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Excluir lançamento',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _deleteWithUndo,
            ),
        ],
      ),
      // Rodapé dentro do body, e não em bottomNavigationBar: o body encolhe
      // quando o teclado abre, o bottomNavigationBar fica atrás dele. Assim o
      // Salvar sobe junto com o teclado e nunca fica escondido.
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _fields(context, accounts, account, toAccount)),
                _Footer(
                  competence: competence,
                  onSave: _saving
                      ? null
                      : () => _save(account, toAccount, competence, accounts),
                  // Lançar vários seguidos: só ao criar (editar volta à lista).
                  onSaveAndNew: _saving || _isEditing
                      ? null
                      : () => _save(
                          account,
                          toAccount,
                          competence,
                          accounts,
                          andNew: true,
                        ),
                  showSaveAndNew: !_isEditing,
                  lastSaved: _lastSaved,
                ),
              ],
            ),
    );
  }

  Widget _fields(
    BuildContext context,
    List<Account> accounts,
    Account? account,
    Account? toAccount,
  ) {
    final checking = accounts.where((a) => !a.kind.isCard).toList();
    final cards = accounts.where((a) => a.kind.isCard).toList();
    final balances = ref.watch(accountBalancesProvider).value ?? const {};
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);

    Widget chips(
      String label,
      List<Account> options,
      int? selected,
      void Function(int) onSelect, {
      String Function(Account)? labelOf,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in options)
                ChoiceChip(
                  avatar: Icon(accountIcon(a), size: 18),
                  label: Text(
                    labelOf?.call(a) ?? accountLabel(a, all: accounts),
                  ),
                  selected: a.id == selected,
                  onSelected: (_) => setState(() {
                    onSelect(a.id);
                    _suggestDescription(accounts);
                  }),
                ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _amount,
          focusNode: _amountFocus,
          autofocus: !_isEditing,
          keyboardType: TextInputType.number,
          inputFormatters: [CentsInputFormatter()],
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: InputDecoration(
            labelText: 'Valor',
            hintText: 'R\$ 0,00',
            errorText:
                (_submitted && CentsInputFormatter.parse(_amount.text) == 0
                    ? 'Informe o valor'
                    : null) ??
                _shownAmountError,
            errorMaxLines: 3,
          ),
          onChanged: (_) => setState(() => _lastSaved = null),
        ),
        const SizedBox(height: 16),
        // Grade 2×2 fixa, não Wrap: num Wrap os chips mudavam de linha conforme
        // o tipo escolhido (a posição de cada um pulava). Quatro tipos também
        // não cabem lado a lado num celular de 360dp.
        for (var row = 0; row < _formTypes.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final type in _formTypes.skip(row).take(2)) ...[
                if (type != _formTypes[row]) const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    // O rótulo ocupa a largura toda para o texto ficar centrado.
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(type.label, textAlign: TextAlign.center),
                    ),
                    selected: _type == type,
                    onSelected: switch (type) {
                      // Cartão só aceita despesa nesta versão.
                      EntryType.income when account?.kind.isCard ?? false => null,
                      // Precisa de duas contas.
                      EntryType.transfer when checking.length < 2 => null,
                      // Precisa de um cartão e de uma conta para pagar.
                      EntryType.billPayment
                          when cards.isEmpty || checking.isEmpty =>
                        null,
                      _ => (_) => setState(() {
                        _type = type;
                        if (!type.hasDestination) _toAccountId = null;
                        _suggestDescription(accounts);
                      }),
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        ...switch (_type) {
          EntryType.transfer => [
            chips('De', checking, account?.id, (id) {
              _accountId = id;
              if (_toAccountId == id) _toAccountId = null;
            }),
            const SizedBox(height: 16),
            chips(
              'Para',
              [
                for (final a in checking)
                  if (a.id != account?.id) a,
              ],
              toAccount?.id,
              (id) => _toAccountId = id,
            ),
          ],
          EntryType.billPayment => [
            chips(
              'Cartão',
              cards,
              toAccount?.id,
              (id) {
                _toAccountId = id;
                // Sai da conta dona do cartão, se ele tiver uma (dá para trocar).
                final owner = cards
                    .firstWhere((c) => c.id == id)
                    .linkedAccountId;
                if (owner != null) _accountId = owner;
              },
              labelOf: (card) {
                final open = -(balances[card.id] ?? 0);
                return open > 0
                    ? '${card.name} · ${Formatters.money(open)} em aberto'
                    : card.name;
              },
            ),
            const SizedBox(height: 16),
            chips('Sai de', checking, account?.id, (id) => _accountId = id),
            // Ao editar, o juros já é um gasto à parte (editável na lista): o
            // campo só existe ao registrar um pagamento novo.
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _interest,
                keyboardType: TextInputType.number,
                inputFormatters: [CentsInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Juros e encargos desta fatura (opcional)',
                  hintText: 'R\$ 0,00',
                  helperText:
                      'Se a fatura do banco veio maior que o em aberto no app, '
                      'coloque aqui a diferença (juros, multa, IOF). Ela vira um '
                      'gasto no cartão.',
                  helperMaxLines: 3,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (toAccount != null) _billSummary(-(balances[toAccount.id] ?? 0)),
            ],
          ],
          // Entrada só em conta; despesa em conta (débito, pix) ou cartão (crédito).
          EntryType.income => [
            chips('Conta', checking, _accountId, (id) => _accountId = id),
          ],
          _ => [chips('Onde', accounts, _accountId, (id) => _accountId = id)],
        },
        if (_submitted && account == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _type.hasDestination ? 'Escolha de onde sai' : 'Escolha a conta',
              style: errorStyle,
            ),
          ),
        if (_submitted && _type.hasDestination && toAccount == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _type == EntryType.billPayment
                  ? 'Escolha o cartão'
                  : 'Escolha para onde vai',
              style: errorStyle,
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: 'Descrição',
            errorText: _submitted && _description.text.trim().isEmpty
                ? 'Informe a descrição'
                : null,
          ),
          // Só digitação do usuário chega aqui (mudar .text por código não chama
          // onChanged) — daí marcar como "dele" e parar de sugerir.
          onChanged: (_) => setState(() => _descriptionEdited = true),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.event_outlined),
          label: Text('Data: ${Formatters.date(_date)}'),
          onPressed: _pickDate,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Observação (opcional)'),
        ),
      ],
    );
  }

  /// Ajuste de saldo: só leitura + excluir. Editar o valor não faz sentido — o
  /// ajuste é a diferença de um momento; para corrigir, ajusta-se de novo.
  Widget _adjustmentView(
    BuildContext context,
    Entry entry,
    List<Account> accounts,
  ) {
    final account = accounts.where((a) => a.id == entry.accountId).firstOrNull;
    final sign = entry.type == EntryType.adjustmentIncrease ? '+' : '−';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuste de saldo'),
        actions: [
          IconButton(
            tooltip: 'Excluir lançamento',
            icon: const Icon(Icons.delete_outline),
            onPressed: _saving ? null : _deleteWithUndo,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$sign ${Formatters.money(entry.amountCents)}',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (account != null) accountLabel(account),
              Formatters.date(entry.date),
            ].join(' · '),
          ),
          const SizedBox(height: 24),
          Text(
            'Ajustes são criados em Contas e cartões → conta → Ajustar saldo, '
            'para o saldo do app bater com o do banco. Para desfazer, exclua.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// O mês que o repositório vai gravar: usa a mesma regra dele (inclusive a do
  /// dia do fechamento do cartão), para o "Vai para" nunca discordar.
  YearMonth _competence(Account account, int startDay) => competenceForAccount(
    date: _date,
    kind: account.kind,
    closingDay: account.closingDay,
    closingDayInCurrent: account.closingDayInCurrent,
    monthStartDay: startDay,
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Tudo o que o aviso do valor depende: se mudar, o aviso deixa de valer.
  String get _situation =>
      '${_type.name}|$_accountId|$_toAccountId|${_date.millisecondsSinceEpoch}|'
      '${_amount.text}|${_interest.text}';

  /// Juros e encargos informados (só existem em pagamento novo).
  int get _interestCents => _type == EntryType.billPayment && !_isEditing
      ? CentsInputFormatter.parse(_interest.text)
      : 0;

  /// Linha ao vivo do pagamento: quanto fica em aberto depois, ou "quitada".
  /// Pagar menos que a fatura é permitido: a diferença continua no cartão e
  /// entra na próxima fatura, como no banco.
  Widget _billSummary(int openCents) {
    final paid = CentsInputFormatter.parse(_amount.text);
    final interest = _interestCents;
    // Sem valor, sem nada a pagar ou passando do que dá para pagar: sem resumo
    // (o erro aparece ao salvar; dizer "quitada" aqui enganaria).
    if (paid == 0 || openCents + interest <= 0 || paid > openCents + interest) {
      return const SizedBox.shrink();
    }
    final outcome = billPaymentOutcome(
      openCents: openCents,
      paidCents: paid,
      interestCents: interest,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        outcome.isSettled
            ? 'Fatura quitada.'
            : '${Formatters.money(outcome.openAfterCents)} continuam em aberto '
                  'e entram na próxima fatura.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String? get _shownAmountError =>
      _amountErrorFor == _situation ? _amountError : null;

  /// As regras de dinheiro da transferência e do pagamento de fatura (ver
  /// `payment_rules.dart`). Vale **só aqui**, no formulário: a importação grava
  /// histórico sem os saldos iniciais e não pode ser barrada por elas.
  ///
  /// Confere o saldo **na data do lançamento** e, ao editar, sem o efeito do
  /// próprio lançamento (senão a transferência bloquearia a si mesma).
  Future<String?> _moneyRuleReason(
    Account account,
    Account? toAccount,
    int cents,
  ) async {
    if (_type != EntryType.transfer && _type != EntryType.billPayment) {
      return null;
    }
    final repo = ref.read(entriesRepositoryProvider);
    final original = _original;

    Future<int> balanceWithoutThisEntry(int accountId) async {
      var balance = await repo.balanceOf(accountId, today: _date);
      if (original != null &&
          !DateUtils.dateOnly(original.date).isAfter(DateUtils.dateOnly(_date))) {
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

    if (_type == EntryType.transfer) {
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
      interestCents: _interestCents,
    );
  }

  /// Limpa o que é de um lançamento só (valor, descrição, observação, juros) e
  /// mantém o que costuma repetir (tipo, contas e data), para lançar o próximo.
  void _resetForNext(List<Account> accounts) {
    setState(() {
      _amount.clear();
      _interest.clear();
      _note.clear();
      _description.clear();
      _descriptionEdited = false;
      _submitted = false;
      _saving = false;
      _amountError = null;
      _amountErrorFor = null;
      _suggestDescription(accounts);
    });
    _amountFocus.requestFocus();
  }

  Future<void> _save(
    Account? account,
    Account? toAccount,
    YearMonth? competence,
    List<Account> accounts, {
    bool andNew = false,
  }) async {
    setState(() => _submitted = true);
    final cents = CentsInputFormatter.parse(_amount.text);
    final hasDestination = _type.hasDestination;
    if (account == null ||
        (hasDestination && toAccount == null) ||
        cents == 0 ||
        _description.text.trim().isEmpty) {
      return;
    }

    final blocked = await _moneyRuleReason(account, toAccount, cents);
    if (blocked != null) {
      if (!mounted) return;
      setState(() {
        _amountError = blocked;
        _amountErrorFor = _situation;
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(entriesRepositoryProvider);
      final draft = EntryDraft(
        id: widget.entryId,
        accountId: account.id,
        toAccountId: hasDestination ? toAccount!.id : null,
        type: _type,
        description: _description.text,
        amountCents: cents,
        date: _date,
        note: _note.text,
      );
      final interest = _interestCents;
      if (interest > 0) {
        // Juros e encargos da fatura: um gasto no cartão (entra nos totais do
        // mês, ao contrário de um ajuste de saldo). Vai na MESMA transação do
        // pagamento — ou entram os dois, ou nenhum.
        await repo.saveAll([
          EntryDraft(
            accountId: toAccount!.id,
            type: EntryType.expense,
            description: 'Juros e encargos da fatura',
            amountCents: interest,
            date: _date,
          ),
          draft,
        ]);
      } else {
        await repo.save(draft);
      }
      // Leva a tela do mês para onde o lançamento foi parar — reforça a regra
      // de virada em vez de o lançamento "sumir" do mês que estava aberto.
      if (competence != null) {
        ref.read(selectedMonthProvider.notifier).select(competence);
      }
      if (!mounted) return;
      if (andNew) {
        // Confirmação no rodapé, e não num SnackBar: o SnackBar cobriria o
        // próprio botão "Salvar e novo" bem quando se quer tocar nele de novo.
        final saved = 'Salvo: ${draft.description.trim()} · ${Formatters.money(cents)}';
        _resetForNext(accounts);
        setState(() => _lastSaved = saved);
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
    }
  }

  /// Exclui na hora e oferece **Desfazer** por alguns segundos, em vez de
  /// perguntar antes: perguntar "tem certeza?" todo mundo responde "sim" sem ler,
  /// e o erro só aparece depois. O aviso fica no messenger do app (não na tela),
  /// então continua visível na lista para onde voltamos.
  Future<void> _deleteWithUndo() async {
    final entry = _original;
    if (entry == null) return;
    final repo = ref.read(entriesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.delete(entry.id);
    if (!mounted) return;
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Lançamento excluído.'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'Desfazer', onPressed: () => repo.restore(entry)),
        ),
      );
  }
}

/// Rodapé fixo: "Vai para" + Salvar.
///
/// Lançar é a ação do dia a dia e o formulário é mais alto que a tela de um
/// celular pequeno — não dá para exigir rolagem. O "Vai para" fica colado no
/// Salvar porque é na hora de confirmar que importa saber o mês.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.competence,
    required this.onSave,
    this.onSaveAndNew,
    this.showSaveAndNew = false,
    this.lastSaved,
  });

  /// Confirmação do último "Salvar e novo" (nula = nada a mostrar).
  final String? lastSaved;

  final YearMonth? competence;
  final VoidCallback? onSave;

  /// "Salvar e novo": grava e deixa o formulário pronto para o próximo. Só ao
  /// criar; [showSaveAndNew] esconde o botão ao editar.
  final VoidCallback? onSaveAndNew;
  final bool showSaveAndNew;

  @override
  Widget build(BuildContext context) {
    final month = competence;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lastSaved != null) ...[
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(lastSaved!, style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (month != null) ...[
              _CompetenceHint(month: month),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (showSaveAndNew) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSaveAndNew,
                      child: const Text('Salvar e novo', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(onPressed: onSave, child: const Text('Salvar')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompetenceHint extends StatelessWidget {
  const _CompetenceHint({required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vai para: ${month.label}',
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
