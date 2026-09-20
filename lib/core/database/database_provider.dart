import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'database_provider.g.dart';

/// Instância única do banco para todo o app.
///
/// `keepAlive` porque abrir e fechar a conexão a cada tela seria desperdício —
/// o banco vive enquanto o app viver. Nos testes, sobrescreva este provider com
/// um `AppDatabase(NativeDatabase.memory())`.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
}
