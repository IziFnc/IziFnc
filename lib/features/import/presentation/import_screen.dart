import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../accounts/presentation/account_form_screen.dart';
import '../../accounts/presentation/account_label.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../entries/domain/competence.dart';
import '../../entries/domain/entry_type.dart';
import '../../entries/presentation/month_providers.dart';
import '../../entries/presentation/month_screen.dart';
import '../data/llm_table_locator.dart';
import '../data/xlsx_workbook.dart';
import '../domain/build_import_plan.dart';
import '../domain/import_error_message.dart';
import '../domain/import_plan.dart';
import '../domain/parsed_row.dart';
import '../../settings/presentation/ai_settings_screen.dart';
import '../../settings/presentation/ai_slots_controller.dart';
import 'import_providers.dart';

/// Importar lançamentos de uma aba da planilha — uma aba (mês) por vez.
///
/// Fluxo em passos dentro da mesma tela (não sub-rotas: é uma feature de uso
/// ocasional, não precisa inflar o router): escolher arquivo -> escolher aba
/// -> mapear banco/tipo para conta -> revisar -> confirmar.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  static const String path = '/importar';

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

enum _Step { pickFile, pickSheet, mapBanks, preview, done }

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Step _step = _Step.pickFile;
  bool _busy = false;
  String? _error;

  /// O texto técnico do erro atual (a exceção crua), em segundo plano.
  String? _errorDetail;

  /// O erro atual é falta de chave de IA (e não falha do provedor).
  bool _missingKey = false;

  /// Preenchida quando a reserva respondeu no lugar do provedor principal.
  String? _fallbackNote;

  /// Linhas que o mapeamento escolhido impede de importar (ex.: origem e
  /// destino da transferência na mesma conta) — somam-se aos erros de leitura.
  List<String> _planErrors = const [];

  XlsxWorkbook? _workbook;
  String? _sheetName;
  ParsedSheetData? _parsed;

  /// Chave de mapeamento (banco|tipo) -> conta escolhida.
  final Map<String, int> _mapped = {};

  /// Chaves que o usuário marcou "não importar": é assim que se importa só uma
  /// parte da aba. Sempre disjunto de [_mapped] (escolher um tira do outro).
  final Set<String> _skipped = {};

  /// Quantas linhas ficaram de fora por esses bancos pulados (para a prévia).
  int _leftOut = 0;

  /// Uma entrada por (banco, tipo) distinto encontrado na aba, na ordem em
  /// que apareceram.
  List<(String banco, SourceTipo tipo)> _pairs = [];

  List<ImportPlanRow> _plan = [];
  int _savedCount = 0;

  @override
  Widget build(BuildContext context) {
    // O fluxo lê estes providers com `.future` no meio do caminho (ao escolher a
    // aba e ao confirmar). Eles descartam sozinhos quando ninguém os observa e,
    // com a importação aberta pelo menu (que troca a tela), nenhuma outra tela
    // os mantém vivos: a leitura falhava com "provider disposed during loading
    // state". Observar aqui, em todos os passos, os mantém vivos até sair.
    ref.watch(accountsProvider);
    ref.watch(monthStartDayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Importar planilha')),
      drawer: const AppDrawer(current: AppDestination.importSheet),
      body: switch (_step) {
        _Step.pickFile => _pickFileStep(),
        _Step.pickSheet => _pickSheetStep(),
        _Step.mapBanks => _mapBanksStep(),
        _Step.preview => _previewStep(),
        _Step.done => _doneStep(),
      },
    );
  }

  Widget _centeredMessage(Widget child) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: child));

  /// Mostra o erro em português (ver `describeImportError`) e guarda o detalhe
  /// técnico para o banner.
  void _fail(Object e, String during) {
    final message = describeImportError(e, during: during);
    setState(() {
      _busy = false;
      _error = message.text;
      _errorDetail = message.detail;
      _missingKey = e is LlmLocatorException && e.missingKey;
    });
  }

  Widget _errorBanner() {
    final error = _error;
    if (error == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final detail = _errorDetail;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText(
                'Detalhe técnico: $detail',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          // Falta de chave não é falha do provedor: leva direto a quem resolve.
          if (_missingKey)
            TextButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Configurar chave'),
              onPressed: () => context.push(AiSettingsScreen.path),
            ),
        ],
      ),
    );
  }

  /// Avisa que a reserva respondeu no lugar do provedor principal — a reserva
  /// costuma ser paga, então isso não pode acontecer em silêncio.
  Widget _fallbackBanner() {
    final note = _fallbackNote;
    if (note == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.onTertiaryContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(note, style: TextStyle(color: colors.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }

  // --- Passo 1: escolher arquivo -------------------------------------------

  /// O que precisa estar pronto antes: contas cadastradas (a planilha cita
  /// bancos e cartões) e uma chave de IA (é ela que acha as tabelas). Sem isso o
  /// botão fica desligado, em vez de a pessoa escolher arquivo e aba e só então
  /// esbarrar no erro.
  Widget _pickFileStep() {
    final theme = Theme.of(context);
    final hasAccounts = ref.watch(accountsProvider).value?.isNotEmpty ?? false;
    final aiConfigured = ref.watch(aiConfiguredProvider);
    final hasAi = aiConfigured.value ?? false;
    final checking = !aiConfigured.hasValue; // ainda lendo o Keystore
    final ready = hasAccounts && hasAi;

    return Column(
      children: [
        _errorBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.upload_file_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Importar a sua planilha',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha o arquivo .xlsx para importar uma aba (mês) por vez.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text('Antes de começar', style: theme.textTheme.titleSmall),
              _ChecklistRow(
                done: hasAccounts,
                title: 'Contas e cartões cadastrados',
                hint: 'A planilha cita bancos e cartões: cadastre os que você usa.',
                actionLabel: 'Cadastrar',
                onAction: () => context.push(AccountFormScreen.newPath),
              ),
              _ChecklistRow(
                done: hasAi,
                checking: checking,
                title: 'Chave de IA configurada',
                hint: 'A IA acha onde ficam as tabelas na aba. A Groq tem plano grátis.',
                actionLabel: 'Configurar',
                onAction: () => context.push(AiSettingsScreen.path),
              ),
              const _InfoRow(
                title: 'Ajuste o saldo inicial de cada conta',
                hint:
                    'Faça isso antes da primeira aba (em Contas e cartões); sem o '
                    'saldo inicial, o "em aberto" dos cartões pode ficar negativo.',
              ),
              const _InfoRow(
                title: 'A planilha precisa ter as tabelas certas',
                hint: '"Despesas Gerais" e "Entrada de Valor". Outro layout provavelmente não será lido.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || !ready ? null : _pickFile,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Escolher arquivo'),
              ),
              if (!ready && !checking)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Faça os itens pendentes acima para escolher o arquivo.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
      _errorDetail = null;
      _missingKey = false;
    });
    try {
      final bytes = await ref.read(importFilePickerProvider)();
      if (bytes == null) {
        setState(() => _busy = false);
        return;
      }
      final workbook = XlsxWorkbook.open(bytes);
      setState(() {
        _workbook = workbook;
        _busy = false;
        _step = _Step.pickSheet;
      });
    } catch (e) {
      _fail(e, 'abrir o arquivo');
    }
  }

  // --- Passo 2: escolher aba -----------------------------------------------

  Widget _pickSheetStep() {
    final workbook = _workbook!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A chamada ao LLM pode levar vários segundos (e mais, se o provedor
        // estiver sobrecarregado e houver nova tentativa) — sem isto a tela
        // fica idêntica e parece que o toque não pegou.
        if (_busy) const LinearProgressIndicator(),
        _errorBanner(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Qual aba (mês) importar?'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            _busy
                ? 'Localizando as tabelas… pode levar alguns segundos.'
                : 'Este passo precisa de internet — um serviço externo ajuda a '
                      'localizar as tabelas na aba.',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final name in workbook.sheetNames)
                ListTile(
                  title: Text(name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _pickSheet(name),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickSheet(String name) async {
    setState(() {
      _busy = true;
      _error = null;
      _errorDetail = null;
      _missingKey = false;
    });
    try {
      final grid = _workbook!.readSheet(name);
      final located = await extractTablesWithAi(
        grid,
        sheetName: name,
        locator: ref.read(llmTableLocatorProvider),
      );
      final parsed = parseSheet(located.tables);

      // Inclui o destino das transferências e o cartão das faturas, que podem
      // nem ter compra nenhuma na aba.
      final pairs = parsed.mappingPairs;

      // Já deixa escolhido o que dá para adivinhar: conta com o mesmo nome do
      // banco, ou o que ficou salvo de uma importação anterior. Sem isso, quem
      // importa dez abas do histórico refaz o mesmo mapeamento dez vezes.
      final mappings = ref.read(importMappingRepositoryProvider);
      final accounts = await ref.read(accountsProvider.future);
      for (final (banco, tipo) in pairs) {
        final suggestion = await mappings.suggest(banco, tipo, accounts);
        if (suggestion != null) {
          _mapped[bankMappingKey(banco, tipo)] = suggestion.id;
        }
      }

      if (!mounted) return;
      setState(() {
        _skipped.clear(); // "não importar" vale só para a aba em que foi escolhido
        _sheetName = name;
        _parsed = parsed;
        _pairs = pairs;
        _fallbackNote = located.note;
        _busy = false;
        _step = _Step.mapBanks;
      });
    } catch (e) {
      _fail(e, 'ler essa aba');
    }
  }

  // --- Passo 3: mapear banco/tipo -> conta ----------------------------------

  Widget _mapBanksStep() {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    // Cada banco precisa de uma decisão (conta ou "não importar"), e pelo menos
    // um tem de entrar: assim dá para importar só uma parte da aba.
    final canContinue = canContinueMapping(
      keys: [for (final (banco, tipo) in _pairs) bankMappingKey(banco, tipo)],
      mapped: _mapped,
      skipped: _skipped,
    );

    return Column(
      children: [
        _errorBanner(),
        _fallbackBanner(),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Para qual conta ou cartão vai cada um? '
            'Marque "Não importar" nos que quiser deixar de fora.',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (banco, tipo) in _pairs)
                _BankMappingTile(
                  banco: banco,
                  tipo: tipo,
                  accounts: accounts,
                  selected: _mapped[bankMappingKey(banco, tipo)],
                  skipped: _skipped.contains(bankMappingKey(banco, tipo)),
                  onSelect: (id) => setState(() {
                    final key = bankMappingKey(banco, tipo);
                    _mapped[key] = id;
                    _skipped.remove(key);
                  }),
                  onSkip: () => setState(() {
                    final key = bankMappingKey(banco, tipo);
                    _skipped.add(key);
                    _mapped.remove(key);
                  }),
                  onCreateAccount: () async {
                    await context.push(AccountFormScreen.newPath);
                  },
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              onPressed: canContinue && !_busy ? _buildPlan : null,
              child: const Text('Continuar'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _buildPlan() async {
    setState(() => _busy = true);
    final parsed = _parsed!;
    final entries = ref.read(entriesRepositoryProvider);
    final mappingRepo = ref.read(importMappingRepositoryProvider);

    final plan = await buildImportPlan(
      parsed: parsed,
      mapped: _mapped,
      skipped: _skipped,
      isDuplicate: (d) => entries.hasDuplicate(
        accountId: d.accountId,
        toAccountId: d.toAccountId,
        type: d.type,
        description: d.description,
        amountCents: d.amountCents,
        date: d.date,
      ),
    );

    // Só os pares desta aba: `_mapped` pode ter sobras de uma aba escolhida
    // antes (o usuário volta e troca de aba).
    for (final (nome, tipo) in _pairs) {
      final accountId = _mapped[bankMappingKey(nome, tipo)];
      if (accountId != null) await mappingRepo.remember(nome, tipo, accountId);
    }

    if (!mounted) return;
    setState(() {
      _plan = plan.rows;
      _planErrors = plan.errors;
      _leftOut = plan.leftOutByChoice;
      _busy = false;
      _step = _Step.preview;
    });
  }

  // --- Passo 4: prévia -------------------------------------------------------

  Widget _previewStep() {
    final parsed = _parsed!;
    List<ImportPlanRow> ofType(EntryType type) => [for (final p in _plan) if (p.type == type) p];
    final despesas = ofType(EntryType.expense);
    final entradas = ofType(EntryType.income);
    final transferencias = ofType(EntryType.transfer);
    final faturas = ofType(EntryType.billPayment);
    final toImport = _plan.where((p) => p.include).length;
    final errors = [...parsed.rowErrors, ..._planErrors];

    return Column(
      children: [
        _errorBanner(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$toImport de ${_plan.length} lançamento(s) serão importados de "$_sheetName": '
            '${despesas.length} despesa(s), ${entradas.length} entrada(s), '
            '${transferencias.length} transferência(s) e '
            '${faturas.length} pagamento(s) de fatura. '
            'Desmarque o que não quiser.'
            '${_leftOut == 0 ? '' : ' $_leftOut linha(s) ficaram de fora nos bancos que você marcou "Não importar".'}'
            '${errors.isEmpty ? '' : ' ${errors.length} linha(s) com erro foram ignoradas.'}',
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (despesas.isNotEmpty) _sectionHeader('Despesas', despesas),
              for (final p in despesas) _PlanTile(plan: p, onToggle: _toggle),
              if (entradas.isNotEmpty) _sectionHeader('Entradas', entradas),
              for (final p in entradas) _PlanTile(plan: p, onToggle: _toggle),
              if (transferencias.isNotEmpty) _sectionHeader('Transferências', transferencias),
              for (final p in transferencias) _PlanTile(plan: p, onToggle: _toggle),
              if (faturas.isNotEmpty) _sectionHeader('Pagamentos de fatura', faturas),
              for (final p in faturas) _PlanTile(plan: p, onToggle: _toggle),
              if (errors.isNotEmpty) ...[
                const _SectionHeader('Ignoradas por erro'),
                for (final message in errors)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      message,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              onPressed: toImport == 0 || _busy ? null : _confirm,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Importar $toImport lançamento(s)'),
            ),
          ),
        ),
      ],
    );
  }

  void _toggle(ImportPlanRow plan) => setState(() => plan.include = !plan.include);

  /// Cabeçalho de uma seção da prévia, com "Desmarcar todas / Marcar todas":
  /// tirar uma seção inteira (ex.: as despesas) é um toque, não uma por uma.
  Widget _sectionHeader(String label, List<ImportPlanRow> rows) {
    final allOn = rows.every((p) => p.include);
    return _SectionHeader(
      label,
      trailing: TextButton(
        onPressed: () => setState(() {
          for (final p in rows) {
            p.include = !allOn;
          }
        }),
        child: Text(allOn ? 'Desmarcar todas' : 'Marcar todas'),
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
      _errorDetail = null;
      _missingKey = false;
    });
    final included = _plan.where((p) => p.include).toList();
    try {
      await ref.read(entriesRepositoryProvider).saveAll([
        for (final p in included) p.toDraft(),
      ]);

      // Leva a tela do mês para o mês da maioria dos lançamentos importados.
      final startDay = await ref.read(monthStartDayProvider.future);
      final accounts = await ref.read(accountsProvider.future);
      final counts = <dynamic, int>{};
      for (final p in included) {
        final account = accounts.where((a) => a.id == p.accountId).firstOrNull;
        if (account == null) continue;
        final competence = competenceForAccount(
          date: p.row.data,
          kind: account.kind,
          closingDay: account.closingDay,
          closingDayInCurrent: account.closingDayInCurrent,
          monthStartDay: startDay,
        );
        counts[competence] = (counts[competence] ?? 0) + 1;
      }
      if (counts.isNotEmpty) {
        final month = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        ref.read(selectedMonthProvider.notifier).select(month);
      }

      if (!mounted) return;
      setState(() {
        _savedCount = included.length;
        _busy = false;
        _step = _Step.done;
      });
    } catch (e) {
      _fail(e, 'gravar os lançamentos');
    }
  }

  // --- Passo 5: concluído ----------------------------------------------------

  Widget _doneStep() {
    return _centeredMessage(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('$_savedCount lançamento(s) importado(s).'),
          const SizedBox(height: 24),
          FilledButton(
            // `go`, não `pop`: a importação é aberta pelo menu (que troca a tela), então
            // não há tela por baixo para desempilhar.
            onPressed: () => context.go(MonthScreen.path),
            child: const Text('Voltar para o mês'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          ?trailing,
        ],
      ),
    );
  }
}

class _BankMappingTile extends StatelessWidget {
  const _BankMappingTile({
    required this.banco,
    required this.tipo,
    required this.accounts,
    required this.selected,
    required this.skipped,
    required this.onSelect,
    required this.onSkip,
    required this.onCreateAccount,
  });

  final String banco;
  final SourceTipo tipo;
  final List<Account> accounts;
  final int? selected;

  /// O usuário marcou este banco como "não importar".
  final bool skipped;
  final void Function(int accountId) onSelect;
  final VoidCallback onSkip;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final wantCard = tipo == SourceTipo.credito;
    final options = accounts.where((a) => a.kind.isCard == wantCard).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$banco (${tipo == SourceTipo.credito ? 'crédito' : 'débito'})',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in options)
                ChoiceChip(
                  avatar: Icon(accountIcon(a), size: 18),
                  label: Text(accountLabel(a, all: accounts)),
                  selected: a.id == selected,
                  onSelected: (_) => onSelect(a.id),
                ),
              // Sempre disponível, inclusive sem conta cadastrada: é como se
              // importa só uma parte da aba.
              ChoiceChip(
                avatar: const Icon(Icons.block, size: 18),
                label: const Text('Não importar'),
                selected: skipped,
                onSelected: (_) => onSkip(),
              ),
              if (options.isEmpty)
                OutlinedButton(
                  onPressed: onCreateAccount,
                  child: Text(
                    wantCard ? 'Cadastre um cartão para "$banco"' : 'Cadastre uma conta para "$banco"',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.onToggle});

  final ImportPlanRow plan;
  final void Function(ImportPlanRow plan) onToggle;

  @override
  Widget build(BuildContext context) {
    final row = plan.row;
    final reasonText = switch (plan.reason) {
      ImportSkipReason.duplicate => 'já importado antes',
      ImportSkipReason.suspiciousDate => 'data fora do padrão da aba — confira',
      null => null,
    };
    return CheckboxListTile(
      value: plan.include,
      onChanged: (_) => onToggle(plan),
      title: Text(plan.description),
      subtitle: Text(
        [
          Formatters.date(row.data),
          Formatters.money(row.valorCents),
          // Nome cru da planilha; a conta/cartão de verdade é a do mapeamento.
          ?switch (row.kind) {
            ParsedKind.transfer => '${row.banco} → ${row.destino}',
            ParsedKind.billPayment => '${row.banco} → cartão ${row.destino}',
            _ => null,
          },
          ?reasonText,
        ].join(' · '),
        style: reasonText == null
            ? null
            : TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// Um item da lista "Antes de começar": feito (✓) ou pendente, com o atalho que
/// resolve a pendência.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.done,
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.onAction,
    this.checking = false,
  });

  final bool done;

  /// Ainda descobrindo (ex.: lendo a chave do Keystore): sem ✓ nem atalho.
  final bool checking;
  final String title;
  final String hint;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pending = !done && !checking;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: checking
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? colors.primary : colors.onSurfaceVariant,
            ),
      title: Text(title),
      subtitle: pending ? Text(hint) : null,
      trailing: pending ? TextButton(onPressed: onAction, child: Text(actionLabel)) : null,
    );
  }
}

/// Um lembrete da lista "Antes de começar" (sem estado feito/pendente).
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(hint),
    );
  }
}
