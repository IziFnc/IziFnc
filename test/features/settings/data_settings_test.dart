import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/core/database/repositories.dart';
import 'package:izifnc/core/utils/formatters.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/settings/data/backup_service.dart';
import 'package:izifnc/features/settings/data/settings_repository.dart';
import 'package:izifnc/features/settings/presentation/backup_actions.dart';
import 'package:izifnc/features/settings/presentation/settings_providers.dart';

import '../../support/menu.dart';
import '../../support/real_fonts.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  group('restaurar troca o banco vivo do app', () {
    late Directory tmp;
    late File dbFile;
    late BackupService service;
    late ProviderContainer container;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('izifnc_restore_');
      dbFile = File('${tmp.path}/izifnc.sqlite');
      service = BackupService(
        databaseFile: () async => dbFile,
        workDir: () async => Directory('${tmp.path}/work'),
        currentSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      container = ProviderContainer(
        overrides: [
          // Igual ao app de verdade: um banco em arquivo, fechado ao descartar.
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase(dbFile));
            ref.onDispose(db.close);
            return db;
          }),
          backupServiceProvider.overrideWithValue(service),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<List<String>> accountNames() async {
      final db = container.read(appDatabaseProvider);
      return [for (final a in await db.select(db.accounts).get()) a.name];
    }

    test('depois de restaurar, o app enxerga os dados do backup e guarda uma cópia dos de antes', () async {
      // O backup: um banco com a conta "Do backup".
      final source = AppDatabase(NativeDatabase(File('${tmp.path}/origem.sqlite')));
      await AccountsRepository(source, EntriesRepository(source))
          .create(name: 'Do backup', kind: AccountKind.checking);
      final backupBytes = await service.export(source);
      await source.close();

      // O app de agora, com outros dados.
      final db = container.read(appDatabaseProvider);
      await AccountsRepository(db, EntriesRepository(db))
          .create(name: 'De agora', kind: AccountKind.checking);
      expect(await accountNames(), ['De agora']);

      await container.read(backupActionsProvider).restore(backupBytes);

      expect(await accountNames(), ['Do backup'], reason: 'o app já lê o banco restaurado');
      expect(identical(container.read(appDatabaseProvider), db), isFalse, reason: 'banco novo, o velho foi descartado');

      final copies = await service.safetyCopies();
      expect(copies, hasLength(1));
      final copy = AppDatabase(NativeDatabase(copies.single));
      addTearDown(copy.close);
      expect([for (final a in await copy.select(copy.accounts).get()) a.name], ['De agora'],
          reason: 'os dados de antes ficaram guardados');
    });

    test('exportar pelo app dá um arquivo que o próprio app aceita', () async {
      final db = container.read(appDatabaseProvider);
      await AccountsRepository(db, EntriesRepository(db))
          .create(name: 'Bradesco', kind: AccountKind.checking);
      final actions = container.read(backupActionsProvider);

      final bytes = await actions.exportBytes();

      expect(await actions.inspect(bytes), isA<BackupValid>());
    });

    test('marcar o backup guarda a data e "último backup" a acompanha', () async {
      final sub = container.listen(lastBackupProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(lastBackupProvider.future), equals(null));

      await container.read(backupActionsProvider).markExported();
      final settings = await container.read(settingsRepositoryProvider).watchLastBackup().first;

      expect(settings, isNotNull);
      expect(DateTime.now().difference(settings!).inMinutes, lessThan(1));
    });
  });

  group('tela Dados', () {
    late AppDatabase db;
    late SettingsRepository settings;

    setUp(() {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      settings = SettingsRepository(db, EntriesRepository(db));
    });
    tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

    Future<void> openData(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            tourEnabledProvider.overrideWithValue(false),
          ],
          child: const IziFncApp(),
        ),
      );
      await tester.pumpAndSettle();
      await goViaMenu(tester, 'Configurações');
      await tester.tap(find.text('Dados'));
      await tester.pumpAndSettle();
    }

    testWidgets('sem backup nenhum: diz "nunca" e avisa', (tester) async {
      await openData(tester);

      expect(find.text('Último backup: nunca'), findsOneWidget);
      expect(find.text('Você ainda não salvou nenhum backup.'), findsOneWidget);
      expect(find.text('Salvar backup'), findsOneWidget);
      expect(find.text('Restaurar de um arquivo'), findsOneWidget);
    });

    testWidgets('com backup recente: mostra a data e não avisa', (tester) async {
      final recent = DateTime.now().subtract(const Duration(days: 3));
      await settings.markBackup(recent);
      await openData(tester);

      expect(find.text('Último backup: ${Formatters.date(recent)}'), findsOneWidget);
      expect(find.textContaining('Já faz mais de 30 dias'), findsNothing);
      expect(find.textContaining('nenhum backup'), findsNothing);
    });

    testWidgets('com backup antigo (mais de 30 dias): avisa', (tester) async {
      await settings.markBackup(DateTime.now().subtract(const Duration(days: 45)));
      await openData(tester);

      expect(find.text('Já faz mais de 30 dias.'), findsOneWidget);
    });
  });
}
