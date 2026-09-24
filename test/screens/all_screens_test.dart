import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/accounts/presentation/account_form_screen.dart';
import 'package:izifnc/features/accounts/presentation/accounts_screen.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/entries/presentation/entry_form_screen.dart';
import 'package:izifnc/features/import/presentation/import_screen.dart';
import 'package:izifnc/features/settings/data/settings_repository.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/data/llm_slot.dart';
import 'package:izifnc/features/import/presentation/import_providers.dart';
import 'package:izifnc/features/settings/presentation/ai_settings_screen.dart';
import 'package:izifnc/features/settings/presentation/data_settings_screen.dart';
import 'package:izifnc/features/settings/presentation/general_settings_screen.dart';
import 'package:izifnc/features/settings/presentation/settings_screen.dart';

import '../support/real_fonts.dart';

/// Rede de segurança de layout (feat 0016): cada tela do app, em cada tamanho de
/// texto e em cada tema, tem de montar **sem overflow nem exceção**.
///
/// Usa a Roboto de verdade (ver `real_fonts.dart`): com a fonte de teste padrão
/// o resultado não diria nada sobre o aparelho. Os dados têm nomes compridos de
/// propósito, porque é assim que o layout quebra na vida real.
///
/// **Tela nova = uma linha em [_screens].**
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;
  late EntriesRepository entries;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    final conta = await accounts.create(
      name: 'Banco Cooperativo do Nordeste Brasileiro',
      kind: AccountKind.checking,
    );
    final outra = await accounts.create(name: 'C6', kind: AccountKind.checking);
    final cartao = await accounts.create(
      name: 'Cartão Platinum Internacional Diners',
      kind: AccountKind.creditCard,
      linkedAccountId: conta,
      closingDay: 22,
      dueDay: 5,
    );
    await entries.adjustBalance(accountId: conta, target: 123456789);
    Future<void> add(int account, EntryType type, String description, int cents, {int? to}) =>
        entries.save(
          EntryDraft(
            accountId: account,
            toAccountId: to,
            type: type,
            description: description,
            amountCents: cents,
            date: DateTime.now(),
            note: 'Observação comprida para conferir a quebra de linha na lista',
          ),
        );
    await add(conta, EntryType.income, 'Salário de setembro com o adiantamento do 13º', 987654321);
    await add(cartao, EntryType.expense, 'Supermercado Atacadão Ribeirão Preto Loja 12', 1234567);
    await add(conta, EntryType.transfer, 'Transferência para reserva de emergência', 250000, to: outra);
    await add(conta, EntryType.billPayment, 'Pagamento fatura Cartão Platinum Internacional', 150000, to: cartao);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  /// Sobe o app do zero no tamanho de texto e no tema pedidos e abre [screen].
  Future<void> pumpScreen(WidgetTester tester, _Screen screen, double scale, _Mode mode) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.platformBrightnessTestValue =
        mode == _Mode.dark ? Brightness.dark : Brightness.light;
    await SettingsRepository(db, entries).setHighContrast(mode == _Mode.highContrast);

    // Chaves de IA em memória (o Keystore não existe no teste), com a Principal
    // e a Reserva preenchidas: é o cartão mais alto da tela.
    final aiStore = MemoryAiSlotsStore()
      ..seed(AiSlot.primary, const LlmSlot(kind: LlmServiceKind.groq, apiKey: 'gsk_principal_1234'))
      ..seed(
        AiSlot.backup,
        const LlmSlot(
          kind: LlmServiceKind.openaiCompatible,
          apiKey: 'sk-reserva-9876',
          baseUrl: 'https://api.provedor-com-nome-bem-comprido.example.com/v1',
          model: 'modelo-com-nome-longo-de-verdade-1234',
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          aiSlotsStoreProvider.overrideWithValue(aiStore),
          tourEnabledProvider.overrideWithValue(false),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    await screen.open(tester);
    await tester.pumpAndSettle();
  }

  for (final screen in _screens) {
    testWidgets('${screen.name}: sem overflow em nenhum tamanho de texto e tema', (tester) async {
      // Celular comum em pé (360×800 dp, a "janela" de referência do Android).
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      for (final scale in _textScales) {
        for (final mode in _Mode.values) {
          await pumpScreen(tester, screen, scale, mode);
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.name} · texto ${scale}x · ${mode.label}',
          );
        }
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
  }

  // Acessibilidade (auditoria de UX da feat 0020): alvo de toque de 48 dp e todo
  // toque com rótulo para leitor de tela, em texto normal e grande, tema claro e
  // escuro. O contraste (`textContrastGuideline`) ficou de fora de propósito: ele
  // mede pixels da captura de teste e acusou falso positivo em texto escuro sobre
  // fundo claro ("Saldos hoje", 1,17:1); confira contraste no aparelho.
  for (final screen in _screens) {
    testWidgets('${screen.name}: acessibilidade (alvo de toque e rótulo)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      final problems = <String>[];
      for (final scale in const [1.0, 1.3]) {
        for (final mode in const [_Mode.light, _Mode.dark]) {
          await pumpScreen(tester, screen, scale, mode);
          for (final (name, guideline) in [
            ('alvo de toque', androidTapTargetGuideline),
            ('rótulo', labeledTapTargetGuideline),
          ]) {
            final result = await guideline.evaluate(tester);
            if (!result.passed) {
              for (final line in _summarize(result.reason ?? '')) {
                problems.add('[$name · texto ${scale}x · ${mode.label}] $line');
              }
            }
          }
        }
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      semantics.dispose();
      final known = _knownA11yProblems[screen.name];
      if (known != null) {
        // Achado conhecido, com dono e prazo: o teste exige que o problema AINDA
        // exista, para a exceção sair da lista assim que for corrigido.
        expect(problems, isNotEmpty, reason: 'corrigido? tire "${screen.name}" de _knownA11yProblems ($known)');
        return;
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}

/// Problemas de acessibilidade já conhecidos: a tela e o achado que a corrige. Sai
/// daqui quando a correção entrar. (Vazio desde a 0022: as linhas de saldo de 28–34 dp
/// viraram linhas de 48 dp na folha de situação.)
const _knownA11yProblems = <String, String>{};

/// O relatório de uma checagem de acessibilidade traz o dump inteiro do nó de
/// semântica; aqui vira uma linha por problema: «rótulo» — mensagem curta.
List<String> _summarize(String reason) {
  final flat = reason.replaceAll(RegExp(r'\s+'), ' ');
  final found = RegExp(
    r'(?:label: "([^"]*)"|merge boundary[^)]*\)|SemanticsNode#\d+\([^"]*?\)):? ?'
    r'(expected tap target size of at least Size\([^)]*\), but found Size\([^)]*\)|'
    r'Expected contrast ratio of at least [\d.]+ but found [\d.]+ for a font size of [\d.]+)',
  );
  final lines = [
    for (final m in found.allMatches(flat)) '«${(m.group(1) ?? 'sem rótulo').replaceAll(r'\n', ' ')}» — ${m.group(2)}',
  ];
  return lines.isEmpty ? [flat] : lines;
}

/// 0,85 é o "Pequeno" do app; 2,0 é o maior que o Android oferece.
const _textScales = [0.85, 1.0, 1.3, 2.0];

enum _Mode {
  light('claro'),
  dark('escuro'),
  highContrast('alto contraste');

  const _Mode(this.label);
  final String label;
}

class _Screen {
  const _Screen(this.name, this.open);
  final String name;
  final Future<void> Function(WidgetTester tester) open;
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

Future<void> _go(WidgetTester tester, String path) async {
  _router(tester).go(path);
  await tester.pumpAndSettle();
}

/// Toca no que existir na tela; com texto grande o alvo pode ficar abaixo da
/// dobra, então rola até ele antes (e falha se o alvo nem existir).
Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget, reason: 'alvo do toque não encontrado');
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
}

Future<void> _pickType(WidgetTester tester, EntryType type) =>
    _tap(tester, find.widgetWithText(ChoiceChip, type.label));

final _screens = <_Screen>[
  _Screen('Início (com dados)', (tester) async {}),
  _Screen('Início · menu aberto', (tester) => _tap(tester, find.byType(DrawerButton))),
  _Screen('Início · situação (folha de detalhes)', (tester) => _tap(tester, find.text('Em conta'))),
  _Screen('Início · busca aberta', (tester) => _tap(tester, find.byTooltip('Buscar'))),
  _Screen(
    'Início · filtros',
    (tester) => _tap(tester, find.byTooltip('Filtrar e ordenar')),
  ),
  _Screen('Contas e cartões', (tester) => _go(tester, AccountsScreen.path)),
  _Screen('Nova conta', (tester) => _go(tester, AccountFormScreen.newPath)),
  _Screen('Novo cartão', (tester) async {
    await _go(tester, AccountFormScreen.newPath);
    await _tap(tester, find.text('Cartão'));
  }),
  _Screen('Editar cartão', (tester) => _go(tester, '/contas/3')),
  _Screen('Lançamento · despesa', (tester) => _go(tester, EntryFormScreen.newPath)),
  _Screen('Lançamento · entrada', (tester) async {
    await _go(tester, EntryFormScreen.newPath);
    await _pickType(tester, EntryType.income);
  }),
  _Screen('Lançamento · transferência', (tester) async {
    await _go(tester, EntryFormScreen.newPath);
    await _pickType(tester, EntryType.transfer);
  }),
  _Screen('Lançamento · pagar fatura', (tester) async {
    await _go(tester, EntryFormScreen.newPath);
    await _pickType(tester, EntryType.billPayment);
  }),
  _Screen('Lançamento · editar', (tester) => _go(tester, '/lancamento/1')),
  _Screen('Importar planilha', (tester) => _go(tester, ImportScreen.path)),
  _Screen('Configurações', (tester) => _go(tester, SettingsScreen.path)),
  _Screen('Configurações · Geral', (tester) => _go(tester, GeneralSettingsScreen.path)),
  _Screen('Configurações · Dados', (tester) => _go(tester, DataSettingsScreen.path)),
  _Screen('Configurações · Inteligência artificial', (tester) => _go(tester, AiSettingsScreen.path)),
];
