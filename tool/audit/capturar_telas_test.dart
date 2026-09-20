// Auditoria de UX: gera imagens PNG de cada tela com dados FICTÍCIOS (banco em
// memória, nada dos dados reais). Não roda no CI (está fora de `test/`); rode com:
//
//     flutter test tool/audit/capturar_telas_test.dart
//
// As imagens vão para a pasta `out` abaixo.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/presentation/import_providers.dart';

import '../../test/support/real_fonts.dart';

/// Onde as imagens são gravadas: a variável `AUDIT_OUT`, ou a pasta temporária do sistema.
final out = Platform.environment['AUDIT_OUT'] ?? '${Directory.systemTemp.path}${Platform.pathSeparator}izifnc-audit';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
    Directory(out).createSync(recursive: true);
  });

  testWidgets('tela por tela', (tester) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    final bradesco = await accounts.create(name: 'Bradesco', kind: AccountKind.checking);
    final c6 = await accounts.create(name: 'C6', kind: AccountKind.checking);
    final caixa = await accounts.create(name: 'Caixa', kind: AccountKind.checking);
    final amazon = await accounts.create(
      name: 'Amazon', kind: AccountKind.creditCard, linkedAccountId: bradesco, closingDay: 22, dueDay: 5,
    );
    final nubank = await accounts.create(
      name: 'Nubank', kind: AccountKind.creditCard, linkedAccountId: c6, closingDay: 28, dueDay: 8,
    );
    await entries.adjustBalance(accountId: bradesco, target: 340000);
    await entries.adjustBalance(accountId: c6, target: 175000);
    await entries.adjustBalance(accountId: caixa, target: 60000);
    final now = DateTime.now();
    Future<void> add(int a, EntryType t, String d, int c, int day, {int? to, String? note}) => entries.save(
      EntryDraft(
        accountId: a, toAccountId: to, type: t, description: d, amountCents: c,
        date: DateTime(now.year, now.month, day.clamp(1, 28)), note: note,
      ),
    );
    await add(bradesco, EntryType.income, 'Salário', 520000, 5);
    await add(bradesco, EntryType.expense, 'Aluguel', 150000, 6, note: 'Pix para a imobiliária');
    await add(bradesco, EntryType.expense, 'Mercado Semanal', 23450, 8);
    await add(c6, EntryType.expense, 'Farmácia', 4890, 9);
    await add(amazon, EntryType.expense, 'Mouse Logitech', 12999, 10);
    await add(amazon, EntryType.expense, 'Livro Clean Architecture', 8990, 12);
    await add(nubank, EntryType.expense, 'Restaurante Japonês', 18700, 13);
    await add(nubank, EntryType.expense, 'Uber', 2350, 14);
    await add(bradesco, EntryType.transfer, 'Reserva de emergência', 50000, 15, to: caixa);
    await add(bradesco, EntryType.billPayment, 'Pagamento fatura Amazon', 12999, 16, to: amazon);
    await add(c6, EntryType.expense, 'Academia', 11990, 17);
    await add(bradesco, EntryType.expense, 'Internet', 9990, 18);
    await add(c6, EntryType.income, 'Freela de design', 85000, 19);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          aiSlotsStoreProvider.overrideWithValue(MemoryAiSlotsStore()),
        ],
        child: RepaintBoundary(key: key, child: const IziFncApp()),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter router() => GoRouter.of(tester.element(find.byType(Scaffold).first));
    Future<void> go(String p) async {
      router().go(p);
      await tester.pumpAndSettle();
    }
    Future<void> tapText(String t) async {
      final f = find.text(t);
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await tester.pumpAndSettle();
    }

    await shot('01_home');
    await tester.tap(find.text('Em conta'));
    await shot('02_home_situacao_detalhe');
    await tester.tapAt(const Offset(180, 60)); // fecha a folha (toque na área escura)
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtrar e ordenar'));
    await shot('03_filtros');
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DrawerButton));
    await shot('04_menu');
    await tester.tapAt(const Offset(350, 400));
    await tester.pumpAndSettle();
    await go('/lancamento/novo');
    await shot('05_form_despesa');
    await tapText('Transferência');
    await shot('06_form_transferencia');
    await tapText('Pagar fatura');
    await shot('07_form_fatura');
    await go('/contas');
    await shot('08_contas');
    await go('/contas/nova');
    await tapText('Cartão');
    await shot('09_conta_cartao');
    await go('/importar');
    await shot('10_importar');
    await go('/configuracoes');
    await shot('11_config');
    await go('/configuracoes/geral');
    await shot('12_geral');
    await go('/configuracoes/ia');
    await shot('13_ia');
    await go('/');
    await tester.scrollUntilVisible(find.text('Mercado Semanal'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Mercado Semanal'));
    await shot('14_editar_lancamento');
    await db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
  });
}
