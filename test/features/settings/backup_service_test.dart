import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/settings/data/backup_service.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tmp;
  late File dbFile;
  late BackupService service;
  late AppDatabase db;

  AppDatabase open(File f) => AppDatabase(NativeDatabase(f));

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('izifnc_backup_');
    dbFile = File('${tmp.path}/izifnc.sqlite');
    service = BackupService(
      databaseFile: () async => dbFile,
      workDir: () async => Directory('${tmp.path}/work'),
      currentSchemaVersion: 7,
    );
    db = open(dbFile);
    final entries = EntriesRepository(db);
    final bradesco = await AccountsRepository(db, entries).create(name: 'Bradesco', kind: AccountKind.checking);
    await entries.save(
      EntryDraft(
        accountId: bradesco,
        type: EntryType.expense,
        description: 'Mercado',
        amountCents: 12345,
        date: DateTime(2026, 9, 1),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Bytes de um banco qualquer criado com o sqlite3 puro.
  Uint8List otherDb(void Function(sql.Database d) build) {
    final f = File('${tmp.path}/outro-${DateTime.now().microsecondsSinceEpoch}.sqlite');
    final d = sql.sqlite3.open(f.path);
    build(d);
    d.close();
    final bytes = f.readAsBytesSync();
    f.deleteSync();
    return bytes;
  }

  test('o nome sugerido leva a data', () {
    expect(BackupService.fileNameFor(DateTime(2026, 9, 5)), 'izifnc-2026-09-05.sqlite');
  });

  test('exportar gera um arquivo SQLite que o próprio app reconhece como válido', () async {
    final bytes = await service.export(db);

    expect(String.fromCharCodes(bytes.sublist(0, 15)), 'SQLite format 3');
    final check = await service.inspect(bytes);
    expect(check, isA<BackupValid>());
    expect((check as BackupValid).schemaVersion, 7);
  });

  test('exportar não deixa arquivos temporários para trás', () async {
    await service.export(db);
    final leftovers = Directory('${tmp.path}/work').listSync();
    expect(leftovers, isEmpty);
  });

  test('ida e volta: exportar, trocar o arquivo e abrir traz os mesmos dados', () async {
    final bytes = await service.export(db);
    await db.close();

    // Outro aparelho: banco vazio, sem nada.
    final other = File('${tmp.path}/novo/izifnc.sqlite');
    final otherService = BackupService(
      databaseFile: () async => other,
      workDir: () async => Directory('${tmp.path}/work2'),
      currentSchemaVersion: 7,
    );
    await otherService.replaceDatabase(bytes);

    final restored = open(other);
    addTearDown(restored.close);
    final accounts = await restored.select(restored.accounts).get();
    final entries = await restored.select(restored.entries).get();
    expect(accounts.map((a) => a.name), ['Bradesco']);
    expect(entries.map((e) => (e.description, e.amountCents)), [('Mercado', 12345)]);
    expect(other.parent.listSync().whereType<File>().map((f) => f.path.split(RegExp(r'[\\/]')).last), ['izifnc.sqlite'],
        reason: 'sem sobra do arquivo de trabalho');
  });

  test('trocar o arquivo apaga os -wal e -shm antigos', () async {
    final bytes = await service.export(db);
    await db.close();
    final wal = File('${dbFile.path}-wal')..writeAsStringSync('lixo');
    final shm = File('${dbFile.path}-shm')..writeAsStringSync('lixo');

    await service.replaceDatabase(bytes);

    expect(wal.existsSync(), isFalse);
    expect(shm.existsSync(), isFalse);
  });

  group('inspect recusa o que não dá para restaurar', () {
    String reasonOf(BackupInspection r) => (r as BackupInvalid).reason;

    test('bytes quaisquer', () async {
      final r = await service.inspect(Uint8List.fromList(List.filled(500, 7)));
      expect(reasonOf(r), contains('não é um banco de dados SQLite'));
    });

    test('arquivo pequeno demais', () async {
      final r = await service.inspect(Uint8List.fromList([1, 2, 3]));
      expect(r, isA<BackupInvalid>());
    });

    test('banco SQLite de outro app', () async {
      final bytes = otherDb((d) {
        d.execute('CREATE TABLE notas (id INTEGER PRIMARY KEY, texto TEXT)');
        d.execute('PRAGMA user_version = 3');
      });
      expect(reasonOf(await service.inspect(bytes)), contains('não parece ser um backup do IziFnc'));
    });

    test('sem user_version (não é banco do drift)', () async {
      final bytes = otherDb((d) {
        d.execute('CREATE TABLE accounts (id INTEGER)');
        d.execute('CREATE TABLE entries (id INTEGER)');
        d.execute('CREATE TABLE app_settings (id INTEGER)');
      });
      expect(await service.inspect(bytes), isA<BackupInvalid>());
    });

    test('feito por uma versão mais nova do app', () async {
      final f = File('${tmp.path}/novo.sqlite');
      f.writeAsBytesSync(await service.export(db));
      final d = sql.sqlite3.open(f.path);
      d.execute('PRAGMA user_version = 99');
      d.close();

      final r = await service.inspect(f.readAsBytesSync());
      expect(reasonOf(r), contains('versão mais nova'));
    });

    test('backup de uma versão mais antiga é aceito (as migrações rodam ao abrir)', () async {
      final f = File('${tmp.path}/velho.sqlite');
      f.writeAsBytesSync(await service.export(db));
      final d = sql.sqlite3.open(f.path);
      d.execute('PRAGMA user_version = 4');
      d.close();

      final r = await service.inspect(f.readAsBytesSync());
      expect(r, isA<BackupValid>());
      expect((r as BackupValid).schemaVersion, 4);
    });
  });

  group('cópia de segurança', () {
    test('guarda o banco atual num arquivo válido', () async {
      final copy = await service.safetyCopy(db);

      expect(copy.existsSync(), isTrue);
      expect(await service.inspect(copy.readAsBytesSync()), isA<BackupValid>());
    });

    test('mantém só as últimas três', () async {
      for (var i = 0; i < 5; i++) {
        await service.safetyCopy(db, now: DateTime(2026, 9, 1 + i));
      }

      final copies = await service.safetyCopies();
      expect(copies, hasLength(BackupService.keepSafetyCopies));
      expect(copies.first.path, contains('2026-09-05'), reason: 'a mais nova primeiro');
      expect(copies.last.path, contains('2026-09-03'));
    });

    test('sem pasta de trabalho ainda: lista vazia, sem erro', () async {
      expect(await service.safetyCopies(), isEmpty);
    });
  });
}
