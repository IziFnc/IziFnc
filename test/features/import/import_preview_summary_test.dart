import 'package:ambrio/core/database/app_database.dart';
import 'package:ambrio/features/accounts/presentation/accounts_providers.dart';
import 'package:ambrio/features/entries/domain/entry_type.dart';
import 'package:ambrio/features/import/domain/import_plan.dart';
import 'package:ambrio/features/import/domain/parsed_row.dart';
import 'package:ambrio/features/import/presentation/import_map_banks_step.dart';
import 'package:ambrio/features/import/presentation/import_preview_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// A prévia em resumo (feat 0049): um cartão por tipo com contagem e total, o que pede
/// revisão destacado, avisos e erros recolhidos, e "Ver mais detalhes" com a lista
/// completa compartilhando a mesma seleção.
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  ParsedRow row(String nome, int cents, {ParsedKind kind = ParsedKind.expense}) => ParsedRow(
    sheetRow: 4,
    nome: nome,
    valorCents: cents,
    data: DateTime(2026, 10, 5),
    banco: 'Azul',
    tipo: SourceTipo.debito,
    observacao: null,
    suspiciousDate: false,
    kind: kind,
  );

  ImportPlanRow item(String nome, int cents, EntryType type, {bool include = true, ImportSkipReason? reason}) =>
      ImportPlanRow(
        row: row(nome, cents),
        accountId: 1,
        type: type,
        description: nome,
        include: include,
        reason: reason,
      );

  late List<ImportPlanRow> plan;
  late int changes;

  setUp(() {
    changes = 0;
    plan = [
      item('Padaria', 1250, EntryType.expense),
      item('Mercado', 23090, EntryType.expense),
      item('Livro', 4500, EntryType.expense, include: false, reason: ImportSkipReason.duplicate),
      item('Salário', 500000, EntryType.income),
    ];
  });

  Future<void> pump(WidgetTester tester, {List<String> planErrors = const []}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ImportPreviewStep(
              banner: const SizedBox.shrink(),
              parsed: const ParsedSheetData(despesas: [], entradas: [], rowErrors: []),
              plan: plan,
              planErrors: planErrors,
              sheetName: 'Outubro',
              leftOut: 0,
              busy: false,
              onChanged: () => setState(() => changes++),
              onConfirm: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('mostra um resumo por tipo, não uma linha por lançamento', (tester) async {
    await pump(tester);

    expect(find.textContaining('3 de 4 lançamento(s) serão importados de "Outubro"'), findsOneWidget);
    expect(find.text('Despesas'), findsOneWidget);
    expect(find.textContaining('2 de 3 marcadas'), findsOneWidget);
    expect(find.text('Entradas'), findsOneWidget);
    expect(find.textContaining('1 de 1 marcada'), findsOneWidget);
    // As linhas uma a uma só aparecem em "Ver mais detalhes".
    expect(find.text('Padaria'), findsNothing);
    expect(find.text('Importar 3 lançamento(s)'), findsOneWidget);
  });

  testWidgets('destaca o que veio desmarcado para revisar', (tester) async {
    await pump(tester);

    expect(find.textContaining('1 linha veio desmarcada para você revisar'), findsOneWidget);
    expect(find.text('1 para revisar'), findsOneWidget);
  });

  testWidgets('o interruptor do grupo marca e desmarca tudo e refaz a contagem', (tester) async {
    await pump(tester);

    // Despesas: 2 de 3 marcadas; ligar o grupo marca a que faltava.
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(find.textContaining('3 de 3 marcadas'), findsOneWidget);
    expect(find.text('Importar 4 lançamento(s)'), findsOneWidget);
    expect(changes, 1);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(find.textContaining('0 de 3 marcadas'), findsOneWidget);
    expect(find.text('Importar 1 lançamento(s)'), findsOneWidget);
  });

  testWidgets('"Ver mais detalhes" lista cada linha e a seleção vale ao voltar', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Ver mais detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da importação'), findsOneWidget);
    expect(find.text('Padaria'), findsOneWidget);
    expect(find.text('Livro'), findsOneWidget);

    await tester.tap(find.text('Padaria'));
    await tester.pumpAndSettle();
    expect(plan.first.include, isFalse, reason: 'a linha mudou no plano compartilhado');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('1 de 3 marcadas'), findsOneWidget);
    expect(find.text('Importar 2 lançamento(s)'), findsOneWidget);
  });

  testWidgets('erros ficam recolhidos num item só', (tester) async {
    await pump(tester, planErrors: const ['Linha 9: faltou valor — ignorada.']);

    expect(find.text('1 linha ignorada por erro'), findsOneWidget);
    expect(find.text('Linha 9: faltou valor — ignorada.'), findsNothing);
    await tester.tap(find.text('1 linha ignorada por erro'));
    await tester.pumpAndSettle();
    expect(find.text('Linha 9: faltou valor — ignorada.'), findsOneWidget);
  });

  testWidgets('aba sem nenhuma linha legível explica o motivo, em vez de uma lista vazia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountsProvider.overrideWith((ref) => Stream.value(const <Account>[]))],
        child: MaterialApp(
          home: Scaffold(
            body: ImportMapBanksStep(
              banner: const SizedBox.shrink(),
              fallbackBanner: const SizedBox.shrink(),
              pairs: const [],
              mapped: const {},
              skipped: const {},
              busy: false,
              onSelect: (_, _, _) {},
              onSkip: (_, _) {},
              onContinue: () {},
              problems: const ['Linha 4 ("Padaria"): sem data, e a aba não tem nenhuma outra data para usar — ignorada.'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nenhuma linha desta aba pôde ser importada'), findsOneWidget);
    expect(find.textContaining('datas são datas de verdade'), findsOneWidget);
    expect(find.textContaining('Linha 4 ("Padaria")'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
  });
}
