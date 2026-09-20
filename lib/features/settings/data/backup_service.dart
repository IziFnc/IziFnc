import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart' as sql;

import '../../../core/database/app_database.dart';

/// O que se descobre ao olhar um arquivo escolhido para restaurar.
sealed class BackupInspection {
  const BackupInspection();
}

/// Arquivo do IziFnc, de uma versão que este app entende.
final class BackupValid extends BackupInspection {
  const BackupValid({required this.schemaVersion});

  /// Versão do banco dentro do arquivo (`user_version`). Menor que a atual:
  /// as migrações de sempre rodam quando o app abrir o banco restaurado.
  final int schemaVersion;
}

/// Não dá para restaurar; [reason] explica em português, para o usuário.
final class BackupInvalid extends BackupInspection {
  const BackupInvalid(this.reason);

  final String reason;
}

/// Exportar, conferir e restaurar o banco como um único arquivo `.sqlite`.
///
/// O backup **é** o banco: cópia exata, sem formato próprio. Não sabe nada de
/// Riverpod nem de tela; quem restaura fecha o banco, chama [replaceDatabase] e
/// reabre (ver `BackupActions`).
class BackupService {
  BackupService({
    required this.databaseFile,
    required this.workDir,
    this.currentSchemaVersion = 0,
  });

  /// Onde o banco vive (fechado, é o arquivo que a restauração sobrescreve).
  final Future<File> Function() databaseFile;

  /// Pasta para os arquivos temporários e as cópias de segurança.
  final Future<Directory> Function() workDir;

  /// Versão do banco que este app cria; arquivos mais novos são recusados.
  final int currentSchemaVersion;

  static const _magic = 'SQLite format 3\u0000';
  static const _requiredTables = {'accounts', 'entries', 'app_settings'};

  /// Quantas cópias de segurança (de antes de uma restauração) ficam guardadas.
  static const keepSafetyCopies = 3;

  /// `izifnc-2026-09-21.sqlite`
  static String fileNameFor(DateTime day) =>
      'izifnc-${day.year}-${_two(day.month)}-${_two(day.day)}.sqlite';

  /// O banco de agora como bytes, num instante consistente.
  ///
  /// `VACUUM INTO` grava uma cópia inteira e coerente mesmo com o banco aberto
  /// e em uso (inclui o que ainda está no arquivo WAL).
  Future<Uint8List> export(AppDatabase db) async {
    final file = await _snapshot(db, 'exportar');
    try {
      return await file.readAsBytes();
    } finally {
      await _delete(file);
    }
  }

  /// Guarda o banco atual antes de uma restauração, mantendo só as últimas
  /// [keepSafetyCopies]. Devolve o arquivo criado.
  Future<File> safetyCopy(AppDatabase db, {DateTime? now}) async {
    final stamp = (now ?? DateTime.now()).toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final dir = await workDir();
    final target = File('${dir.path}${Platform.pathSeparator}antes-de-restaurar-$stamp.sqlite');
    await _vacuumInto(db, target);
    await _pruneSafetyCopies(dir);
    return target;
  }

  /// As cópias de segurança existentes, da mais nova para a mais antiga.
  Future<List<File>> safetyCopies() async {
    final dir = await workDir();
    if (!await dir.exists()) return [];
    final files = [
      for (final e in dir.listSync())
        if (e is File && _isSafetyCopy(e)) e,
    ]..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Confere se [bytes] é um banco do IziFnc que este app consegue abrir.
  Future<BackupInspection> inspect(Uint8List bytes) async {
    if (bytes.length < 100 || String.fromCharCodes(bytes.sublist(0, 16)) != _magic) {
      return const BackupInvalid('Este arquivo não é um banco de dados SQLite.');
    }
    final dir = await workDir();
    await dir.create(recursive: true);
    final probe = File('${dir.path}${Platform.pathSeparator}conferir-${DateTime.now().microsecondsSinceEpoch}.sqlite');
    await probe.writeAsBytes(bytes, flush: true);
    sql.Database? db;
    try {
      db = sql.sqlite3.open(probe.path, mode: sql.OpenMode.readOnly);
      final version = db.select('PRAGMA user_version').first.values.first as int;
      final tables = {
        for (final r in db.select("SELECT name FROM sqlite_master WHERE type = 'table'"))
          r['name'] as String,
      };
      if (version == 0 || !tables.containsAll(_requiredTables)) {
        return const BackupInvalid('Este arquivo não parece ser um backup do IziFnc.');
      }
      if (version > currentSchemaVersion) {
        return const BackupInvalid(
          'Este backup foi feito por uma versão mais nova do IziFnc. Atualize o app e tente de novo.',
        );
      }
      final check = db.select('PRAGMA quick_check').first.values.first;
      if (check != 'ok') {
        return const BackupInvalid('O arquivo está danificado e não pode ser restaurado.');
      }
      return BackupValid(schemaVersion: version);
    } on sql.SqliteException {
      return const BackupInvalid('Não consegui ler este arquivo como um banco do IziFnc.');
    } finally {
      db?.close();
      await _delete(probe);
    }
  }

  /// Troca o arquivo do banco por [bytes]. **O banco tem de estar fechado.**
  ///
  /// Grava num arquivo ao lado e renomeia (uma falha no meio não deixa um banco
  /// pela metade) e apaga os `-wal`/`-shm` velhos, que não valem para o novo.
  Future<void> replaceDatabase(Uint8List bytes) async {
    final target = await databaseFile();
    await target.parent.create(recursive: true);
    final staging = File('${target.path}.restaurando');
    await staging.writeAsBytes(bytes, flush: true);
    await _delete(File('${target.path}-wal'));
    await _delete(File('${target.path}-shm'));
    await staging.rename(target.path);
  }

  Future<File> _snapshot(AppDatabase db, String why) async {
    final dir = await workDir();
    final file = File('${dir.path}${Platform.pathSeparator}$why-${DateTime.now().microsecondsSinceEpoch}.sqlite');
    await _vacuumInto(db, file);
    return file;
  }

  Future<void> _vacuumInto(AppDatabase db, File target) async {
    await target.parent.create(recursive: true);
    await _delete(target); // VACUUM INTO recusa um arquivo que já existe
    await db.customStatement('VACUUM INTO ?', [target.path]);
  }

  Future<void> _pruneSafetyCopies(Directory dir) async {
    final copies = await safetyCopies();
    for (final old in copies.skip(keepSafetyCopies)) {
      await _delete(old);
    }
  }

  bool _isSafetyCopy(File f) => f.uri.pathSegments.last.startsWith('antes-de-restaurar-');

  Future<void> _delete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Um temporário que não sumiu não atrapalha nada.
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
