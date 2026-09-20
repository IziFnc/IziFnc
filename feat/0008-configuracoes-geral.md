# 0008 — Configurações em seções e aba Geral

**Data:** 2026-09-19 · **Status:** ✅ concluído

## O que mudou

- A tela **Configurações** (engrenagem na tela do mês) virou uma **lista de seções**, cada
  uma numa tela própria. Hoje tem uma: **Geral**. Configuração nova entra em
  `settingsSections` (`settings_sections.dart`) com a própria tela e rota, em vez de inchar
  uma tela só.
- **Geral** reúne aparência e acessibilidade; cada mudança vale na hora e fica gravada:
  - **Tema**: Sistema · Claro · Escuro.
  - **Tamanho do texto**: Pequeno · Padrão · Grande · Muito grande. **Multiplica** o tamanho
    que o sistema já aplica (quem usa fonte grande no Android continua com ela).
  - **Alto contraste**: paleta com contraste máximo do Material 3 (`contrastLevel: 1.0`), mesma
    cor-semente.
- Banco **v4 → v5**: três colunas novas em `app_settings` (`theme_mode`, `text_scale`,
  `high_contrast`), todas com valor padrão.

## Por quê

O autor quer separar as configurações por assunto (a tela da IA já estava comprida) e
começar a cuidar de acessibilidade. A lista de seções deixa o caminho aberto para as
próximas (IA na versão dos testadores, "Mês", etc.) sem redesenhar a tela.

Decisões e alternativas descartadas:

- **`themeMode` como índice inteiro**, não texto e sem `CHECK`: a migração fica só
  "adicionar coluna" (mudar `CHECK` obriga o SQLite a recriar a tabela). Valor desconhecido
  lido do banco cai em "Sistema" em vez de derrubar o app.
- **Tamanho do texto como número (`text_scale`)** e as quatro opções só na tela: dá para
  mudar as opções sem migração. `setTextScale` recusa valores fora de 0,8–2,0.
- **Texto soma ao do sistema** (`media.textScaler.scale(1.0) * escolha`), não substitui:
  substituir desfaria uma preferência de acessibilidade que o usuário já fez no aparelho.
- **Fora desta entrega, de propósito:** "Sobre/versão" (pede `package_info_plus`, dependência
  nova, entra junto com o esquema de versão MAJOR.MINOR), ocultar valores, reduzir animações,
  idioma.

## Arquivos tocados

- [`lib/features/settings/domain/appearance.dart`](../lib/features/settings/domain/appearance.dart) — `AppThemeMode`, `TextSize`, `Appearance`.
- [`lib/features/settings/data/settings_repository.dart`](../lib/features/settings/data/settings_repository.dart) e [`settings_table.dart`](../lib/features/settings/data/settings_table.dart) — leitura/gravação e colunas novas.
- [`lib/core/database/app_database.dart`](../lib/core/database/app_database.dart) — passo `from4To5`; schema em `drift_schemas/`.
- [`lib/features/settings/presentation/`](../lib/features/settings/presentation/) — `settings_screen`, `settings_sections`, `general_settings_screen`, `settings_providers`.
- [`lib/app.dart`](../lib/app.dart), [`lib/core/theme/app_theme.dart`](../lib/core/theme/app_theme.dart) — aplicam tema, texto e contraste.
- Testes: `test/features/settings/*`, `test/drift/app_database/migration_test.dart` (v4→v5 preserva dados).

## Como verificar

1. `flutter analyze` e `flutter test` (inclui a migração v4→v5 e os widgets de cada opção).
2. No emulador: engrenagem → **Geral** → trocar tema, arrastar o texto até "Muito grande",
   ligar alto contraste. O app inteiro reage na hora; feche e reabra: continua igual.
3. Instalar por cima de uma versão v4 com dados: contas e lançamentos intactos, tema
   "Sistema".

## Pendências / próximos passos

- Seção "Sobre" (versão) junto com o esquema MAJOR.MINOR.
- 0009 acrescenta a seção **Inteligência artificial** (só na versão dos testadores).
- "Dia de virada do mês" (hoje na tela de contas) pode migrar para Geral na 0014.
