# 0034 — Endurecimento de segurança

**Data:** 2026-10-23 · **Status:** ✅ concluído

## O que mudou

- **Timeout nas chamadas ao provedor de IA:** 60 s ao localizar tabelas, 20 s no "Testar".
  Antes uma conexão pendurada deixava a importação girando para sempre.
- **Tetos no `.xlsx`**, conferidos antes de descompactar: 25 MB de arquivo, 2000 partes,
  100 MB por parte, 250 MB no total. Mensagem própria ("grande demais").
- **Restaurar backup** recusa banco com trigger, view ou tabela que o app não cria.
- **Manifesto Android:** `allowBackup="false"`, regras de extração de dados vazias e
  `networkSecurityConfig` sem tráfego em texto puro; `tool/validar.dart` trava as três.
- **Contrato de privacidade com teste:** o corpo enviado ao provedor não leva número nem
  data nas três implementações. O teste mostrou que o README prometia menos do que sai de
  fato (todas as células de **texto**, inclusive nomes de lançamentos); o README foi
  corrigido para dizer isso.
- **CI:** `permissions: contents: read` e as duas actions fixadas por SHA do commit
  (a tag `v4`/`v2` pode ser movida por quem controla o repositório da action).
- Modelo de ameaças e riscos aceitos no cofre privado (`seguranca/modelo-de-ameacas.md`).

## Por quê

O app é offline, mas tem uma porta para fora (a IA) e três entradas de dados que não
controlamos (planilha, backup, resposta do LLM). Cada ajuste fecha uma lacuna concreta
achada lendo o código, não uma lista genérica.

Descartado por ora: criptografar o backup e certificate pinning (ver modelo de ameaças).

## Arquivos tocados

[llm_table_locator.dart](../lib/features/import/data/llm_table_locator.dart) ·
[xlsx_workbook.dart](../lib/features/import/data/xlsx_workbook.dart) ·
[backup_service.dart](../lib/features/settings/data/backup_service.dart) ·
[AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) ·
[validar.dart](../tool/validar.dart) · testes `llm_timeout`, `llm_privacy`,
`xlsx_workbook`, `backup_service`.

## Como verificar

- `flutter test`; `dart run tool/validar.dart; echo "exit=$?"`.
- Manifesto: `flutter build apk --debug` e ver `allowBackup`, `networkSecurityConfig`,
  `dataExtractionRules` em `build/app/intermediates/merged_manifests/debug/…/AndroidManifest.xml`.

## O que não foi verificado

- Manifesto conferido só em build de **debug**; falta confirmar num APK release assinado.
- Migração de aparelho (`device-transfer`) do Android não foi exercitada num aparelho.
- O teto do `.xlsx` usa o tamanho que o zip **declara**; um zip que mente sobre o tamanho
  não é pego pela conferência prévia (ver riscos aceitos).
- Varredura de dependências **não entrou**: o `dart pub` não tem comando de auditoria
  (`audit` não existe no Dart 3.13). Fica manual (`dart pub outdated`) até haver ferramenta.
- O pin por SHA não se atualiza sozinho; trocar a versão da action passa a ser um passo manual.
- Nada disso foi exercitado contra um provedor de IA de verdade (chaves vencidas).

## Pendências / próximos passos

- Proposta de `v1.0.1` (patch) com estes ajustes, só com o "pode" do autor.
- Cópia do keystore de release fora do PC (ação do autor).
