import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/repositories.dart';
import '../../../core/utils/formatters.dart';
import '../data/accounts_repository.dart';
import '../domain/account_kind.dart';
import 'account_balance_tile.dart';
import 'account_card_fields.dart';
import 'accounts_providers.dart';
import 'adjust_balance_dialog.dart';

/// Criar ou editar uma conta/cartão. O tipo trava depois de criado.
///
/// **Nada é gravado antes do Salvar** — nem o ajuste de saldo. O "Ajustar" do
/// diálogo só prepara o ajuste; o Salvar grava conta e ajuste juntos (feat 0005).
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountId, this.initialKind = AccountKind.checking});

  static const String newPath = '/contas/nova';
  static const String editPattern = '/contas/:id';
  static String editPath(int id) => '/contas/$id';

  final int? accountId;

  /// Tipo pré-selecionado ao criar (ignorado ao editar). Usado pelo tour
  /// guiado e pelo item "Cadastrar um cartão" do `FirstStepsCard` pra abrir
  /// direto em "Cartão".
  final AccountKind initialKind;

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
    if (_isEditing) {
      _load(widget.accountId!);
    } else {
      _kind = widget.initialKind;
    }
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
                    AccountBalanceTile(
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
                  if (isCard)
                    AccountCardFields(
                      cardId: widget.accountId,
                      ownerId: _ownerId,
                      ownerError: _ownerError,
                      onOwnerSelected: (id) => setState(() => _ownerId = id),
                      closingDay: _closingDay,
                      closingError: _closingError,
                      closingInCurrent: _closingInCurrent,
                      onClosingInCurrent: (v) =>
                          setState(() => _closingInCurrent = v),
                      dueDay: _dueDay,
                      dueError: _dueError,
                      onChanged: () => setState(() {}),
                    ),
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
          AdjustBalanceDialog(isCard: _kind.isCard, initial: _pendingAdjust),
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
