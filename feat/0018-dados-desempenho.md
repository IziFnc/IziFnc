# 0018 — Dados e desempenho: backup, índices e limpeza

**Data:** 2026-09-21 · **Status:** ✅ concluído

## O que mudou

- **Backup e restauração** em **Configurações › Dados**:
  - **Salvar backup:** grava o banco inteiro num arquivo `izifnc-AAAA-MM-DD.sqlite`, pelo seletor de
    arquivos do Android (Downloads, Drive, o que o aparelho oferecer).
  - **Restaurar de um arquivo:** confere que é um banco do IziFnc, pede confirmação ("SUBSTITUI todos os
    dados"), guarda antes uma **cópia de segurança** dos dados atuais (as 3 últimas ficam) e troca o banco.
    Se o backup for de uma versão mais antiga, as migrações de sempre rodam ao abrir.
  - **Último backup: dd/mm/aaaa** com aviso quando nunca foi feito ou passou de 30 dias.
- **Desempenho:** dois índices em `entries` — `(account_id, date)` e `(to_account_id)` — para o cálculo de
  saldo, mais um teste com **20 mil lançamentos** (plano de consulta usa o índice; saldos e um mês < 2 s).
- **Migração v6 → v7** (só adiciona: `app_settings.last_backup_at` e os dois índices).
- **Limpeza:** removidos `fl_chart` (sem uso), a pasta `web/` (1,2 MB, fora do APK), o `DriftWebOptions` e
  as notas de web/Chrome do README. `sqlite3` passou a constar no `pubspec` (já vinha com o drift).

## Por quê

O app guarda tudo só no aparelho, e antes da 1.0 faltava uma saída para esses dados: perder ou trocar o
celular apagava tudo. O autor escolheu o **arquivo do banco (.sqlite)** em vez de um formato próprio
(JSON/CSV): é uma cópia exata, sem código de conversão para manter, e restaurar é trocar o arquivo.

- **`VACUUM INTO` para exportar:** gera uma cópia inteira e coerente com o banco aberto e em uso, sem
  depender do arquivo WAL nem de fechar o banco.
- **Restaurar é destrutivo, então:** valida antes (cabeçalho SQLite, `user_version` do drift, tabelas
  `accounts`/`entries`/`app_settings`, `quick_check`), **recusa backup de versão mais nova** que o app, pede
  confirmação e guarda a cópia de segurança. A troca é por arquivo temporário + renomear (falha no meio não
  deixa banco pela metade) e apaga `-wal`/`-shm`. Qualquer falha reabre o banco (nunca sobra app com banco
  fechado).
- **`AppDatabase.close()` idempotente:** a restauração fecha o banco e o provider o fecha de novo ao ser
  descartado.
- **Mesmo arquivo de sempre:** `databaseFile()` devolve `<documentos>/izifnc.sqlite`, o caminho que o
  `drift_flutter` já usava; quem já tinha dados continua com eles.
- **R8/minify não valeu:** o APK arm64 de release mede **21,8 MB**, dominado pelo motor do Flutter
  (`libflutter` 11,7 MB) e pelo código Dart (`libapp` 8,3 MB); o código Java é 0,5 MB. Reduzir isso com R8 não
  compensa o risco de quebrar plugin por reflexão.
- **`android:allowBackup` fica no padrão** (ligado): o backup automático do Google ajuda quem troca de
  celular. As chaves de IA (só na versão dos testadores) ficam no Keystore e **não** vão junto.

## Arquivos tocados

- [`backup_service.dart`](../lib/features/settings/data/backup_service.dart) — exportar, conferir, cópia de segurança, trocar arquivo.
- [`backup_actions.dart`](../lib/features/settings/presentation/backup_actions.dart) e
  [`data_settings_screen.dart`](../lib/features/settings/presentation/data_settings_screen.dart) — a tela e a ligação com o banco vivo.
- [`database_file.dart`](../lib/core/database/database_file.dart), [`app_database.dart`](../lib/core/database/app_database.dart) — caminho do banco, v7, `close()` idempotente.
- `settings_table.dart`, `entries_table.dart`, `settings_repository.dart` — coluna e índices; `markBackup`/`watchLastBackup`.
- `drift_schemas/…/drift_schema_v7.json` e testes gerados; `migration_test.dart` (v6→v7 com dados).
- Testes: `backup_service_test`, `data_settings_test`, `performance_test`; a matriz de telas ganhou "Configurações · Dados".
- Removidos: `web/`, `fl_chart`; README atualizado.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No aparelho (feito no emulador): Configurações › Dados › **Salvar backup** → arquivo em Downloads;
   mude algo (ex.: dia de virada) → **Restaurar** o arquivo → "Backup restaurado." e o dado volta.

## Pendências / próximos passos

- A **migração v6→v7 sobre o banco real** dos testadores fica para o merge na `release/teste-usuarios`
  (o teste de preservação de dados já cobre a estrutura).
- O `.mcp.json` ainda registra o `chrome-devtools`, que só servia ao build web; a remoção é do autor.
- Backup **automático** (agendado) e **na nuvem** não entram: hoje é manual, por escolha.
- As cópias de segurança de antes de uma restauração ficam dentro dos dados do app (não aparecem nos
  Downloads); se um dia precisar, dá para oferecer "recuperar a cópia anterior" na mesma tela.
