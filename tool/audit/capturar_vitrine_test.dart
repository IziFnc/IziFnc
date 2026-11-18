// Dados de demonstração da vitrine do projeto (README e docs/telas): gera um banco
// FICTÍCIO (contas Azul e Verde, cartões Roxo e Âmbar) e, de brinde, capturas de
// tela de teste. Fora de `test/`, não roda no CI.
//
// As capturas do README saem do **app de verdade** num emulador: gere o banco e
// restaure-o por Configurações › Dados › Restaurar de um arquivo:
//
//     AUDIT_DB=ambrio-demo.sqlite AUDIT_OUT=%TEMP%/telas flutter test tool/audit/capturar_vitrine_test.dart
//     adb push ambrio-demo.sqlite /sdcard/Download/
//
// (A renderização de teste é só aproximada: o anel de foco do teste aparece nas imagens.)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ambrio/app.dart';
import 'package:ambrio/core/database/app_database.dart';
import 'package:ambrio/core/database/database_provider.dart';
import 'package:ambrio/features/accounts/data/accounts_repository.dart';
import 'package:ambrio/features/accounts/domain/account_kind.dart';
import 'package:ambrio/features/entries/data/entries_repository.dart';
import 'package:ambrio/features/entries/domain/entry_type.dart';
import 'package:ambrio/features/import/data/ai_slots_store.dart';
import 'package:ambrio/features/import/presentation/import_providers.dart';
import 'package:ambrio/features/settings/data/settings_repository.dart';
import 'package:ambrio/features/settings/domain/appearance.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../test/support/real_fonts.dart';

final out =
    Platform.environment['AUDIT_OUT'] ??
    '${Directory.systemTemp.path}${Platform.pathSeparator}ambrio-vitrine';
final dark = Platform.environment['AUDIT_DARK'] == '1';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
    Directory(out).createSync(recursive: true);
  });

  testWidgets('vitrine', (tester) async {
    // AUDIT_DB=arquivo.sqlite grava também o banco de demonstração (para restaurar num aparelho de teste).
    final dbPath = Platform.environment['AUDIT_DB'];
    if (dbPath != null && File(dbPath).existsSync()) File(dbPath).deleteSync();
    final db = AppDatabase(
      DatabaseConnection(
        dbPath == null ? NativeDatabase.memory() : NativeDatabase(File(dbPath)),
        closeStreamsSynchronously: true,
      ),
    );
    final entries = EntriesRepository(db);
    final accounts = AccountsRepository(db, entries);
    final settings = SettingsRepository(db, entries);
    await settings.skipTour();
    await settings.markPrivacyNoticeSeen(1);
    await settings.markBackup(DateTime.now());
    if (dark) await settings.setThemeMode(AppThemeMode.dark);

    final azul = await accounts.create(
      name: 'Azul',
      kind: AccountKind.checking,
    );
    final verde = await accounts.create(
      name: 'Verde',
      kind: AccountKind.checking,
    );
    final roxo = await accounts.create(
      name: 'Roxo',
      kind: AccountKind.creditCard,
      linkedAccountId: azul,
      closingDay: 22,
      dueDay: 5,
    );
    final ambar = await accounts.create(
      name: 'Âmbar',
      kind: AccountKind.creditCard,
      linkedAccountId: verde,
      closingDay: 28,
      dueDay: 8,
    );
    await entries.adjustBalance(accountId: azul, target: 340000);
    await entries.adjustBalance(accountId: verde, target: 175000);
    final now = DateTime.now();
    Future<void> add(int a, EntryType t, String d, int c, int day, {int? to}) =>
        entries.save(
          EntryDraft(
            accountId: a,
            toAccountId: to,
            type: t,
            description: d,
            amountCents: c,
            date: DateTime(now.year, now.month, day.clamp(1, 28)),
          ),
        );
    await add(azul, EntryType.income, 'Salário', 520000, 5);
    await add(azul, EntryType.expense, 'Aluguel', 150000, 6);
    await add(azul, EntryType.expense, 'Mercado', 23450, 8);
    await add(verde, EntryType.expense, 'Farmácia', 4890, 9);
    await add(roxo, EntryType.expense, 'Livro de design', 8990, 12);
    await add(roxo, EntryType.expense, 'Mouse', 12999, 10);
    await add(ambar, EntryType.expense, 'Jantar', 18700, 13);
    await add(ambar, EntryType.expense, 'Transporte', 2350, 14);
    await add(verde, EntryType.income, 'Freela', 85000, 19);
    await add(azul, EntryType.expense, 'Internet', 9990, 18);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2.0);
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
        child: RepaintBoundary(key: key, child: const AmbrioApp()),
      ),
    );
    await tester.runAsync(
      () => settings.skipTour(),
    ); // o guia desenharia um anel nos alvos
    await tester.pumpAndSettle();
    GoRouter router() =>
        GoRouter.of(tester.element(find.byType(Scaffold).first));
    Future<void> go(String p) async {
      router().go(p);
      await tester.pumpAndSettle();
    }

    await shot('01-inicio');
    await go('/situacao');
    await shot('02-situacao');
    await go('/cartoes/$roxo/pagar');
    await shot('03-pagar-fatura');
    await go('/contas');
    await shot('04-contas');
    await go('/lancamento/novo');
    await shot('05-novo-lancamento');
    await go('/importar');
    await shot('06-importar');
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
  });
}
