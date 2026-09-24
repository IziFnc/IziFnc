import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/accounts/data/accounts_table.dart';
import '../../features/accounts/domain/account_kind.dart';
import '../../features/entries/data/entries_table.dart';
import '../../features/entries/domain/entry_type.dart';
import '../../features/import/data/import_bank_mappings_table.dart';
import '../../features/settings/data/settings_table.dart';
import 'app_database.steps.dart';
import 'database_file.dart';

// `.drift.dart`, não `.g.dart`: o drift gera num alvo próprio (ver build.yaml).
part 'app_database.drift.dart';

/// Banco local do IziFnc (SQLite via Drift).
@DriftDatabase(tables: [Accounts, Entries, AppSettings, ImportBankMappings])
class AppDatabase extends _$AppDatabase {
  /// Construtor para testes, que abrem um banco em memória.
  AppDatabase(super.e);

  /// Banco real do app, no diretório de dados da plataforma (ver
  /// [databaseFile]). O app é só Android: não há build web.
  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'izifnc',
          native: DriftNativeOptions(
            databasePath: () async => (await databaseFile()).path,
          ),
        ),
      );

  Future<void>? _closing;

  /// Pode ser chamado mais de uma vez (a restauração de backup fecha o banco
  /// antes de trocar o arquivo, e o provider fecha de novo ao descartá-lo).
  @override
  Future<void> close() => _closing ??= super.close();

  /// Toda mudança de tabela sobe este número, ganha um passo em [migration] e
  /// exige `dart run drift_dev make-migrations` (guarda o schema e gera testes).
  ///
  /// - v1: contas, lançamentos, configurações (feat 0003)
  /// - v2: `entries.to_account_id` para transferências (feat 0004)
  /// - v3: `accounts.linked_account_id` e o tipo `billPayment` (feat 0006)
  /// - v4: tabela `import_bank_mappings` (feat 0007)
  /// - v5: tema, tamanho do texto e alto contraste em `app_settings` (feat 0008)
  /// - v6: `accounts.closing_day_in_current`, regra do dia do fechamento (feat 0012)
  /// - v7: `app_settings.last_backup_at` e os índices de `entries` para saldo (feat 0018)
  /// - v8: `app_settings.tour_step`, parada atual do tour guiado (feat 0026)
  static const int currentSchemaVersion = 8;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettings)
          .insert(AppSettingsCompanion.insert(id: const Value(1)));
    },
    // Um passo por versão, gerado pelo make-migrations (app_database.steps.dart).
    // `schema` é a foto da tabela naquela versão, não a atual — por isso os
    // passos continuam válidos mesmo depois de mudanças futuras nas tabelas.
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        // Só adiciona a coluna (nula para todos os lançamentos antigos).
        await m.addColumn(schema.entries, schema.entries.toAccountId);
      },
      from2To3: (m, schema) async {
        // Cartões existentes ficam sem conta dona; a tela pede para vincular.
        await m.addColumn(schema.accounts, schema.accounts.linkedAccountId);
        // Na v2, pagar a fatura era uma transferência para o cartão. Agora
        // tem tipo próprio, e transferência é só conta -> conta.
        await customStatement('''
          UPDATE entries SET type = 'billPayment'
          WHERE type = 'transfer'
            AND to_account_id IN (SELECT id FROM accounts WHERE kind = 'creditCard')
        ''');
      },
      from3To4: (m, schema) async {
        // Só cria a tabela nova — nada em accounts/entries muda.
        await m.createTable(schema.importBankMappings);
      },
      from4To5: (m, schema) async {
        // Só adiciona colunas, todas com valor padrão: a linha única de
        // configurações existente passa a valer "segue o sistema, texto normal".
        await m.addColumn(schema.appSettings, schema.appSettings.themeMode);
        await m.addColumn(schema.appSettings, schema.appSettings.textScale);
        await m.addColumn(schema.appSettings, schema.appSettings.highContrast);
      },
      from5To6: (m, schema) async {
        // Só adiciona a coluna, com padrão `false`: os cartões que já existem
        // seguem a regra de sempre (dia do fechamento → fatura seguinte) e
        // nenhum lançamento muda de mês. Só cartão novo nasce `true`.
        await m.addColumn(
          schema.accounts,
          schema.accounts.closingDayInCurrent,
        );
      },
      from6To7: (m, schema) async {
        // Só adiciona (coluna nula = "nunca fez backup" e dois índices): nenhuma
        // linha existente muda.
        await m.addColumn(schema.appSettings, schema.appSettings.lastBackupAt);
        await m.createIndex(schema.entriesAccountDate);
        await m.createIndex(schema.entriesToAccount);
      },
      from7To8: (m, schema) async {
        // Só adiciona a coluna, com padrão 0 ("primeira parada do tour"): quem
        // já usa o app não ganha o tour do zero de repente — a primeira parada
        // é o botão de cadastrar conta, que não existe mais numa conta com
        // contas — então o tour fica "esperando" um alvo que nunca aparece de
        // novo sozinho, sem incomodar ninguém. "Ver o tour de novo" em
        // Configurações continua disponível para quem quiser rever.
        await m.addColumn(schema.appSettings, schema.appSettings.tourStep);
      },
    ),
    beforeOpen: (details) async {
      // SQLite ignora chave estrangeira por padrão. Sem isto, o RESTRICT de
      // `entries.account_id` não faz nada e dá para apagar conta com lançamento.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
