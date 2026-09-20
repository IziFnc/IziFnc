import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/repositories.dart';
import '../data/backup_service.dart';
import 'settings_providers.dart';

/// As operações de backup ligadas ao banco vivo do app. A tela cuida só de
/// escolher/salvar o arquivo e de perguntar ao usuário.
class BackupActions {
  BackupActions(this._ref);

  final Ref _ref;

  BackupService get _service => _ref.read(backupServiceProvider);

  /// O banco de agora, como bytes prontos para salvar.
  Future<Uint8List> exportBytes() => _service.export(_ref.read(appDatabaseProvider));

  /// Anota que o backup foi salvo (alimenta o "último backup" da tela).
  Future<void> markExported() => _ref.read(settingsRepositoryProvider).markBackup(DateTime.now());

  Future<BackupInspection> inspect(Uint8List bytes) => _service.inspect(bytes);

  /// Substitui **todos** os dados pelos de [bytes] (já conferidos com [inspect]).
  ///
  /// 1. guarda uma cópia dos dados atuais; 2. fecha o banco; 3. troca o arquivo;
  /// 4. descarta o provider, que reabre o banco (subindo as migrações se o backup
  /// for de uma versão mais antiga) e refaz tudo o que depende dele.
  ///
  /// Se algo falhar no meio, o banco é reaberto do mesmo jeito: nunca fica o app
  /// com um banco fechado.
  Future<void> restore(Uint8List bytes) async {
    final db = _ref.read(appDatabaseProvider);
    try {
      await _service.safetyCopy(db);
      await db.close();
      await _service.replaceDatabase(bytes);
    } finally {
      _ref.invalidate(appDatabaseProvider);
    }
  }
}

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);
