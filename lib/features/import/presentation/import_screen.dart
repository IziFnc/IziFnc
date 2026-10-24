import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/double_back_to_exit.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../entries/domain/competence.dart';
import '../../entries/presentation/month_providers.dart';
import '../data/llm_table_locator.dart';
import '../data/xlsx_workbook.dart';
import '../domain/build_import_plan.dart';
import '../domain/import_error_message.dart';
import '../domain/import_plan.dart';
import '../domain/parsed_row.dart';
import 'import_banners.dart';
import 'import_done_step.dart';
import 'import_map_banks_step.dart';
import 'import_pick_file_step.dart';
import 'import_pick_sheet_step.dart';
import 'import_preview_step.dart';
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

    final banner = ImportErrorBanner(
      error: _error,
      detail: _errorDetail,
      missingKey: _missingKey,
    );

    return DoubleBackToExit(
      child: Scaffold(
        appBar: AppBar(title: const Text('Importar planilha')),
        drawer: const AppDrawer(current: AppDestination.importSheet),
        body: switch (_step) {
          _Step.pickFile => ImportPickFileStep(
            banner: banner,
            busy: _busy,
            onPickFile: _pickFile,
          ),
          _Step.pickSheet => ImportPickSheetStep(
            sheetNames: _workbook!.sheetNames,
            banner: banner,
            busy: _busy,
            onPick: _pickSheet,
          ),
          _Step.mapBanks => ImportMapBanksStep(
            banner: banner,
            fallbackBanner: ImportFallbackBanner(note: _fallbackNote),
            pairs: _pairs,
            mapped: _mapped,
            skipped: _skipped,
            busy: _busy,
            onSelect: (banco, tipo, id) => setState(() {
              final key = bankMappingKey(banco, tipo);
              _mapped[key] = id;
              _skipped.remove(key);
            }),
            onSkip: (banco, tipo) => setState(() {
              final key = bankMappingKey(banco, tipo);
              _skipped.add(key);
              _mapped.remove(key);
            }),
            onContinue: _buildPlan,
          ),
          _Step.preview => ImportPreviewStep(
            banner: banner,
            parsed: _parsed!,
            plan: _plan,
            planErrors: _planErrors,
            sheetName: _sheetName,
            leftOut: _leftOut,
            busy: _busy,
            onChanged: () => setState(() {}),
            onConfirm: _confirm,
          ),
          _Step.done => ImportDoneStep(savedCount: _savedCount),
        },
      ),
    );
  }

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

  // --- Passo 1: escolher arquivo -------------------------------------------

  /// O que precisa estar pronto antes: contas cadastradas (a planilha cita
  /// bancos e cartões) e uma chave de IA (é ela que acha as tabelas). Sem isso o
  /// botão fica desligado, em vez de a pessoa escolher arquivo e aba e só então
  /// esbarrar no erro.
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
        _skipped
            .clear(); // "não importar" vale só para a aba em que foi escolhido
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
        final month = counts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
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
}
