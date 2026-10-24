import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/repositories.dart';
import '../../../core/utils/cents_input_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/year_month.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/entries_repository.dart';
import '../domain/entry_type.dart';
import 'adjustment_entry_view.dart';
import 'entry_form_fields.dart';
import 'entry_form_logic.dart';
import 'entry_form_footer.dart';
import 'entry_money_rule.dart';
import 'entry_persistence.dart';
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
  late DateTime _date = DateUtils.dateOnly(ref.read(clockProvider)());

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
    final suggestion = suggestedDescription(_type, to);
    if (suggestion == null) {
      _description.clear();
    } else {
      _description.text = suggestion;
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

  /// Verdadeiro quando esta tela é a parada atual do tour guiado (feat 0026)
  /// — usado para não focar "Valor" sozinho e abrir o teclado por cima da
  /// bolha.
  bool get _tourIsHere =>
      ref.watch(tourEnabledProvider) &&
      ref.watch(tourStepProvider).value == TourAnchor.entryTypeGrid.index;

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

    final toAccount = resolveToAccount(_type, accounts, _toAccountId, account);

    // O mês segue a conta de origem, também na transferência e no pagamento.
    final competence = (account == null || startDay == null)
        ? null
        : entryCompetence(account, startDay, _date);

    final adjustment = _adjustment;
    if (adjustment != null) {
      return AdjustmentEntryView(
        entry: adjustment,
        account: accounts.where((a) => a.id == adjustment.accountId).firstOrNull,
        onDelete: _saving ? null : _deleteWithUndo,
      );
    }

    void save({bool andNew = false}) =>
        _save(account, toAccount, competence, accounts, andNew: andNew);

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
                Expanded(child: _fields(account, toAccount, accounts)),
                EntryFormFooter(
                  competence: competence,
                  onSave: _saving ? null : save,
                  // Lançar vários seguidos: só ao criar (editar volta à lista).
                  onSaveAndNew: _saving || _isEditing ? null : () => save(andNew: true),
                  showSaveAndNew: !_isEditing,
                  lastSaved: _lastSaved,
                ),
              ],
            ),
    );
  }

  Widget _fields(Account? account, Account? toAccount, List<Account> accounts) {
    final cards = accounts.where((a) => a.kind.isCard).toList();
    // Seleção de conta: muda o estado e refaz a sugestão de descrição.
    void pick(VoidCallback change) => setState(() {
      change();
      _suggestDescription(accounts);
    });

    return EntryFormFields(
      accounts: accounts,
      account: account,
      toAccount: toAccount,
      balances: ref.watch(accountBalancesProvider).value ?? const {},
      amount: _amount,
      amountFocus: _amountFocus,
      interest: _interest,
      description: _description,
      note: _note,
      type: _type,
      formTypes: entryFormTypes,
      date: _date,
      accountId: _accountId,
      isEditing: _isEditing,
      tourIsHere: _tourIsHere,
      submitted: _submitted,
      amountError: _shownAmountError,
      interestCents: _interestCents,
      onAmountChanged: () => setState(() => _lastSaved = null),
      onTypeSelected: (type) => pick(() {
        _type = type;
        if (!type.hasDestination) _toAccountId = null;
      }),
      onFromSelected: (id) => pick(() {
        _accountId = id;
        if (_toAccountId == id) _toAccountId = null;
      }),
      onToSelected: (id) => pick(() => _toAccountId = id),
      onCardSelected: (id) => pick(() {
        _toAccountId = id;
        // Sai da conta dona do cartão, se ele tiver uma (dá para trocar).
        final owner = cards.firstWhere((c) => c.id == id).linkedAccountId;
        if (owner != null) _accountId = owner;
      }),
      onInterestChanged: () => setState(() {}),
      onPickDate: _pickDate,
      // Só digitação do usuário chega aqui (mudar .text por código não chama
      // onChanged) — daí marcar como "dele" e parar de sugerir.
      onDescriptionTyped: () => setState(() => _descriptionEdited = true),
    );
  }

  Future<void> _pickDate() async {
    final picked = await pickEntryDate(context, _date);
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

  String? get _shownAmountError =>
      _amountErrorFor == _situation ? _amountError : null;

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

    final blocked = await entryMoneyRuleReason(
      repo: ref.read(entriesRepositoryProvider),
      type: _type,
      date: _date,
      original: _original,
      account: account,
      toAccount: toAccount,
      cents: cents,
      interestCents: _interestCents,
    );
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
      await saveEntryWithInterest(
        ref.read(entriesRepositoryProvider),
        draft,
        interestCents: _interestCents,
        cardId: toAccount?.id,
      );
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

  Future<void> _deleteWithUndo() async {
    final entry = _original;
    if (entry == null) return;
    final repo = ref.read(entriesRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.delete(entry.id);
    if (!mounted) return;
    context.pop();
    showEntryDeletedUndo(messenger, repo, entry);
  }
}
