import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/accounts/data/accounts_repository.dart';
import '../../features/entries/data/entries_repository.dart';
import '../../features/import/data/import_mapping_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import 'database_provider.dart';

part 'repositories.g.dart';

// Os repositórios ficam juntos aqui porque dependem uns dos outros (mudar um
// dia de corte recalcula lançamentos). Os construtores recebem o banco puro,
// então os testes de repositório nem precisam do Riverpod.

@Riverpod(keepAlive: true)
EntriesRepository entriesRepository(Ref ref) =>
    EntriesRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
AccountsRepository accountsRepository(Ref ref) => AccountsRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(entriesRepositoryProvider),
);

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => SettingsRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(entriesRepositoryProvider),
);

@Riverpod(keepAlive: true)
ImportMappingRepository importMappingRepository(Ref ref) =>
    ImportMappingRepository(ref.watch(appDatabaseProvider));
