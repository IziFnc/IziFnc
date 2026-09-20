import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/repositories.dart';
import '../../../core/utils/cents_input_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../data/accounts_repository.dart';
import '../domain/account_kind.dart';
import 'accounts_providers.dart';

/// Criar ou editar uma conta/cartão. O tipo trava depois de criado.
///
/// **Nada é gravado antes do Salvar** — nem o ajuste de saldo. O "Ajustar" do
/// diálogo só prepara o ajuste; o Salvar grava conta e ajuste juntos (feat 0005).
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountId});

  static const String newPath = '/contas/nova';
  static const String editPattern = '/contas/:id';
  static String editPath(int id) => '/contas/$id';

  final int? accountId;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _name = TextEditingController();
  final _closingDay = TextEditingController();
  final _dueDay = TextEditingController();

  AccountKind _kind = AccountKind.checking;
  bool _loading = false;
  bool _saving = false;
  bool _submitted = false;

  /// Alvo do "Ajustar saldo" ainda não gravado (mesma semântica de
  /// `adjustBalance`: saldo da conta, ou valor em aberto no cartão).
  int? _pendingAdjust;

  /// Só cartão: a conta dona dele (obrigatória desde a feat 0006).
  int? _ownerId;

  /// Só cartão: a compra feita no dia do fechamento fica na fatura atual
  /// (`true`) ou vai para a próxima. Cartão novo começa em "atual".
  bool _closingInCurrent = true;

  /// Valores como vieram do banco, para saber se há alteração não salva.
  String _loadedName = '';
  String _loadedClosing = '';
  String _loadedDue = '';
  int? _loadedOwner;
  bool _loadedInCurrent = true;

  /// Liberado só ao sair de propósito (salvou, excluiu, confirmou descartar).
  bool _leaving = false;

  bool get _isEditing => widget.accountId != null;

  bool get _isDirty =>
      _pendingAdjust != null ||
      _name.text != _loadedName ||
      _closingDay.text != _loadedClosing ||
      _dueDay.text != _loadedDue ||
      _ownerId != _loadedOwner ||
      _closingInCurrent != _loadedInCurrent;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _load(widget.accountId!);
  }

  Future<void> _load(int id) async {
    setState(() => _loading = true);
    final account = await ref.read(accountsRepositoryProvider).find(id);
    if (!mounted) return;
    if (account == null) {
      _leave();
      return;
    }
    setState(() {
      _name.text = _loadedName = account.name;
      _kind = account.kind;
      _closingDay.text = _loadedClosing = account.closingDay?.toString() ?? '';
      _dueDay.text = _loadedDue = account.dueDay?.toString() ?? '';
      _ownerId = _loadedOwner = account.linkedAccountId;
      _closingInCurrent = _loadedInCurrent = account.closingDayInCurrent;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _closingDay.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  /// Sai da tela sem passar pela confirmação de descartar.
  ///
  /// O pop espera o próximo quadro: o `PopScope` só enxerga `canPop = true`
  /// depois de reconstruir. Popando na hora, o Salvar abriria o "Descartar?".
  void _leave() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  /// `null` = campo vazio; `-1` = preenchido com algo fora de 1..31.
  int? _day(TextEditingController c) {
    if (c.text.isEmpty) return null;
    final day = int.tryParse(c.text);
    return (day != null && day >= 1 && day <= 31) ? day : -1;
  }

  String? get _nameError =>
      _submitted && _name.text.trim().isEmpty ? 'Informe o nome' : null;

  String? get _closingError {
    if (!_submitted) return null;
    return switch (_day(_closingDay)) {
      null => 'Informe o dia de fechamento',
      -1 => 'Um dia de 1 a 31',
      _ => null,
    };
  }

  String? get _dueError =>
      _submitted && _day(_dueDay) == -1 ? 'Um dia de 1 a 31' : null;

  String? get _ownerError =>
      _submitted && _ownerId == null ? 'Escolha a conta dona do cartão' : null;

  @override
  Widget build(BuildContext context) {
    final isCard = _kind.isCard;

    return PopScope(
      canPop: _leaving || !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar conta' : 'Nova conta'),
          actions: [
            if (_isEditing)
              IconButton(
                tooltip: 'Excluir conta',
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving ? null : _delete,
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isEditing) ...[
                    _BalanceTile(
                      isCard: isCard,
                      balance: ref
                          .watch(accountBalancesProvider)
                          .value?[widget.accountId],
                      pendingTarget: _pendingAdjust,
                      onAdjust: _adjust,
                      onUndo: () => setState(() => _pendingAdjust = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SegmentedButton<AccountKind>(
                    segments: [
                      for (final kind in AccountKind.values)
                        ButtonSegment(
                          value: kind,
                          label: Text(kind.label),
                          enabled: !_isEditing,
                        ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.single),
                  ),
                  if (_isEditing)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('O tipo não muda depois de criado.'),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: 'Nome',
                      hintText: isCard
                          ? 'Ex.: Amazon, Bradesco'
                          : 'Ex.: Bradesco, C6',
                      errorText: _nameError,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (isCard) ...[
                    const SizedBox(height: 8),
                    _OwnerPicker(
                      cardId: widget.accountId,
                      selected: _ownerId,
                      error: _ownerError,
                      onSelected: (id) => setState(() => _ownerId = id),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _closingDay,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Dia do fechamento da fatura',
                        helperText: 'Como aparece no app do banco (o "Até" da planilha).',
                        errorText: _closingError,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    // Os bancos divergem sobre a compra feita no próprio dia do
                    // fechamento, então a escolha é do cartão.
                    Text(
                      'Compra no dia do fechamento entra na:',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Fatura atual')),
                        ButtonSegment(value: false, label: Text('Próxima fatura')),
                      ],
                      selected: {_closingInCurrent},
                      onSelectionChanged: (s) =>
                          setState(() => _closingInCurrent = s.single),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Itaú e Mercado Pago: atual · Nubank: próxima. Confira no app do seu banco.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dueDay,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Vence no dia (opcional)',
                        errorText: _dueError,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('Salvar'),
                  ),
                ],
              ),
      ),
    );
  }

  /// Só prepara o ajuste; quem grava é o Salvar.
  Future<void> _adjust() async {
    final target = await showDialog<int>(
      context: context,
      builder: (_) =>
          _AdjustBalanceDialog(isCard: _kind.isCard, initial: _pendingAdjust),
    );
    if (target == null || !mounted) return;
    setState(() => _pendingAdjust = target);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'Você mudou esta conta e não salvou. Sair agora descarta as mudanças.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final hasErrors =
        _nameError != null ||
        (_kind.isCard &&
            (_closingError != null ||
                _dueError != null ||
                _ownerError != null));
    if (hasErrors) return;

    setState(() => _saving = true);
    final repo = ref.read(accountsRepositoryProvider);
    // O SnackBar aparece na tela de trás: pega o messenger antes de sair.
    final messenger = ScaffoldMessenger.of(context);
    final closing = _kind.isCard ? _day(_closingDay) : null;
    final due = _kind.isCard ? _day(_dueDay) : null;
    final adjusting = _pendingAdjust != null;
    try {
      var delta = 0;
      if (_isEditing) {
        delta = await repo.update(
          id: widget.accountId!,
          name: _name.text,
          closingDay: closing,
          dueDay: due,
          linkedAccountId: _kind.isCard ? _ownerId : null,
          closingDayInCurrent: _closingInCurrent,
          adjustTarget: _pendingAdjust,
        );
      } else {
        await repo.create(
          name: _name.text,
          kind: _kind,
          closingDay: closing,
          dueDay: due,
          linkedAccountId: _kind.isCard ? _ownerId : null,
          closingDayInCurrent: _closingInCurrent,
        );
      }
      if (!mounted) return;
      _leave();
      if (adjusting) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              delta == 0
                  ? 'Conta salva. O saldo já batia; nenhum ajuste registrado.'
                  : 'Conta salva. Ajuste de ${delta > 0 ? '+' : '−'} '
                        '${Formatters.money(delta.abs())} registrado.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text('Não dá para desfazer.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(accountsRepositoryProvider).delete(widget.accountId!);
      if (mounted) _leave();
    } on AccountInUseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Esta conta tem ${e.entryCount} '
            '${e.entryCount == 1 ? 'lançamento' : 'lançamentos'}. '
            'Exclua ou mova ${e.entryCount == 1 ? 'ele' : 'eles'} antes.',
          ),
        ),
      );
    } on AccountHasCardsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Esta conta é dona de ${e.cardCount} '
            '${e.cardCount == 1 ? 'cartão' : 'cartões'}. '
            'Vincule ${e.cardCount == 1 ? 'ele' : 'eles'} a outra conta antes.',
          ),
        ),
      );
    }
  }
}

/// "Conta vinculada" do cartão: chips com as contas (nunca outros cartões).
class _OwnerPicker extends ConsumerWidget {
  const _OwnerPicker({
    required this.cardId,
    required this.selected,
    required this.error,
    required this.onSelected,
  });

  final int? cardId;
  final int? selected;
  final String? error;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owners = [
      for (final a in ref.watch(accountsProvider).value ?? const [])
        if (!a.kind.isCard && a.id != cardId) a,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conta vinculada', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'A conta dona do cartão. É dela que sai o pagamento da fatura.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (owners.isEmpty)
          const Text(
            'Cadastre a conta primeiro (ex.: Bradesco), depois o cartão.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in owners)
                ChoiceChip(
                  avatar: const Icon(Icons.account_balance_outlined, size: 18),
                  label: Text(a.name),
                  selected: a.id == selected,
                  onSelected: (_) => onSelected(a.id),
                ),
            ],
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}

/// Saldo de hoje (ou "em aberto" no cartão) + o ajuste pendente, se houver.
class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.isCard,
    required this.balance,
    required this.pendingTarget,
    required this.onAdjust,
    required this.onUndo,
  });

  final bool isCard;

  /// Saldo com sinal; no cartão é negativo (dívida). `null` enquanto carrega.
  final int? balance;

  /// O que vai virar ao salvar, na mesma unidade que o usuário digitou (saldo
  /// da conta, ou valor em aberto no cartão). `null` = nada pendente.
  final int? pendingTarget;

  final VoidCallback onAdjust;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = balance;
    final shown = value == null
        ? '…'
        : Formatters.money(isCard ? -value : value);
    final pending = pendingTarget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isCard ? 'Em aberto hoje' : 'Saldo hoje'),
                  Text(shown, style: theme.textTheme.titleLarge),
                  if (pending != null)
                    Text(
                      '→ ${Formatters.money(pending)} ao salvar',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (pending != null)
              IconButton(
                tooltip: 'Desfazer ajuste',
                icon: const Icon(Icons.undo),
                onPressed: onUndo,
              ),
            OutlinedButton(
              onPressed: onAdjust,
              child: Text(pending == null ? 'Ajustar saldo' : 'Alterar ajuste'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pede o valor real (o que o banco mostra). Devolve o alvo em centavos:
/// conta corrente com sinal (cheque especial = negativo); cartão, o valor em
/// aberto. Não grava nada — quem grava é o Salvar da tela.
class _AdjustBalanceDialog extends StatefulWidget {
  const _AdjustBalanceDialog({required this.isCard, this.initial});

  final bool isCard;

  /// Ajuste pendente anterior, para editar em vez de redigitar.
  final int? initial;

  @override
  State<_AdjustBalanceDialog> createState() => _AdjustBalanceDialogState();
}

class _AdjustBalanceDialogState extends State<_AdjustBalanceDialog> {
  late final _value = TextEditingController(
    text: CentsInputFormatter.format((widget.initial ?? 0).abs()),
  );
  late bool _negative = (widget.initial ?? 0) < 0;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final cents = CentsInputFormatter.parse(_value.text);
    Navigator.of(context).pop(_negative ? -cents : cents);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustar saldo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isCard
                ? 'Quanto o banco mostra em aberto nesta fatura hoje? '
                      'Ao salvar a conta, a diferença vira um ajuste no histórico.'
                : 'Qual o saldo que o banco mostra hoje? '
                      'Ao salvar a conta, a diferença vira um ajuste no histórico.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [CentsInputFormatter()],
            decoration: InputDecoration(
              labelText: widget.isCard ? 'Em aberto' : 'Saldo no banco',
              hintText: 'R\$ 0,00',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (!widget.isCard)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Saldo negativo'),
              value: _negative,
              onChanged: (v) => setState(() => _negative = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Ajustar')),
      ],
    );
  }
}
