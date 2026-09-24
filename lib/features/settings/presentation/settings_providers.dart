import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_file.dart';
import '../../../core/database/repositories.dart';
import '../data/backup_service.dart';
import '../domain/appearance.dart';

part 'settings_providers.g.dart';

/// Versão e build do app (Configurações › Geral › Sobre). É o que o usuário
/// cita ao reportar um problema; vem do `pubspec.yaml`, sem duplicar.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// O serviço de backup: os arquivos temporários e as cópias de segurança ficam
/// numa pasta própria, dentro dos dados do app.
@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) => BackupService(
  databaseFile: databaseFile,
  workDir: () async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}backups');
  },
  currentSchemaVersion: AppDatabase.currentSchemaVersion,
);

/// Quando o usuário exportou o banco pela última vez (nulo = nunca).
@riverpod
Stream<DateTime?> lastBackup(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchLastBackup();

/// Tema, tamanho do texto e contraste escolhidos pelo usuário.
@riverpod
Stream<Appearance> appearance(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchAppearance();

/// Em qual parada do tour guiado (feat 0026) a pessoa está — ver `TourAnchor`.
@riverpod
Stream<int> tourStep(Ref ref) => ref.watch(settingsRepositoryProvider).watchTourStep();
