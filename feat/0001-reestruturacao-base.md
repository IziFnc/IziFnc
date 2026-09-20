# 0001 — Reestruturação base

**Data:** 2026-09-13 · **Status:** ✅ concluído

## O que mudou

O projeto saiu do template `flutter create` e virou um esqueleto de app de finanças,
sem ainda ter nenhuma feature de finanças.

- **Versionamento:** o projeto virou um repositório git (não era). O commit `17849be`
  guarda o template original para a reestruturação aparecer como um diff legível.
- **`_local/`** — anotações de trabalho, ignorada pelo git, dividida em `jason/`
  (decisões de produto do autor) e `claude/` (decisões técnicas e contexto entre sessões).
- **`feat/`** — esta pasta, versionada, com o histórico de entregas.
- **MCPs de teste visual** em [`.mcp.json`](../.mcp.json): `chrome-devtools` e `mobile-mcp`.
- **Esqueleto do app:** Riverpod 3 + go_router + Drift/SQLite + intl pt-BR, com uma tela
  placeholder que prova o pipeline inteiro de pé.
- **Assets web do Drift:** `web/sqlite3.wasm` e `web/drift_worker.js`, pareados com drift 2.35.0.

## Por quê

**Riverpod feature-first em vez de Bloc.** Projeto de uma pessoa só. Bloc entrega mais
explicitude ao custo de muito boilerplate por tela, o que num app pessoal se paga mal.
Riverpod dá injeção de dependência, cache e invalidação sem cerimônia, e testa bem
via override de provider.

**Drift/SQLite local em vez de nuvem.** Finanças pessoais são o caso de uso mais óbvio
de offline-first: você lança um gasto na fila do mercado, sem sinal. Zero custo de
servidor, zero risco de vazamento, e SQL relacional modela transação/categoria/conta
muito melhor que um NoSQL. Sync na nuvem, se um dia fizer falta, entra atrás da camada
de repositório sem mexer nas telas.

**Dinheiro como `int` em centavos, nunca `double`.** Ponto flutuante acumula erro de
arredondamento; num app de finanças isso aparece como saldo que não fecha. A conversão
para decimal acontece só na exibição, em [`Formatters`](../lib/core/utils/formatters.dart).

**`_local/` separada por autor.** Sem a divisão, as anotações viram um caderno único onde
não dá para saber o que é decisão firme do autor e o que é inferência do Claude. A
regra é: o Claude lê `jason/` mas nunca escreve lá.

**`feat/` além do git log.** Mensagem de commit boa descreve o *o quê*. O *por quê* e as
alternativas descartadas não cabem nela, e é exatamente isso que se perde em seis meses.

**Assets web do Drift baixados agora, não depois.** O Drift na web precisa do
`sqlite3.wasm` e do `drift_worker.js` servidos em `web/`. Como nenhuma tela toca o banco
ainda, a falta deles não quebraria nada hoje — quebraria na primeira leitura do banco
em Chrome, com um erro que não aponta para a causa. Baixar já evita essa sessão perdida.

## Arquivos tocados

**Criados**

- [`lib/main.dart`](../lib/main.dart) — `ProviderScope` + carga dos símbolos de data pt-BR
- [`lib/app.dart`](../lib/app.dart) — `MaterialApp.router`, tema, locale
- [`lib/core/router/app_router.dart`](../lib/core/router/app_router.dart)
- [`lib/core/theme/app_theme.dart`](../lib/core/theme/app_theme.dart)
- [`lib/core/database/app_database.dart`](../lib/core/database/app_database.dart) — Drift, ainda sem tabelas
- [`lib/core/database/database_provider.dart`](../lib/core/database/database_provider.dart)
- [`lib/core/utils/formatters.dart`](../lib/core/utils/formatters.dart)
- [`lib/features/dashboard/presentation/dashboard_screen.dart`](../lib/features/dashboard/presentation/dashboard_screen.dart)
- [`.mcp.json`](../.mcp.json), `feat/`, `_local/` (não versionada)
- `web/sqlite3.wasm`, `web/drift_worker.js`

**Modificados**

- [`pubspec.yaml`](../pubspec.yaml) — description real + dependências
- [`.gitignore`](../.gitignore) — `/_local/` e `.env`
- [`analysis_options.yaml`](../analysis_options.yaml) — exclui `**/*.g.dart` da análise
- [`test/widget_test.dart`](../test/widget_test.dart) — o teste do contador virou smoke test + testes do `Formatters`
- [`web/index.html`](../web/index.html), [`web/manifest.json`](../web/manifest.json) — título, descrição e cores do IziFc

## Como verificar

```bash
flutter analyze                      # No issues found!
flutter test                         # All tests passed! (3 testes)
dart run build_runner build          # wrote N outputs, sem erro
flutter run -d chrome --web-port=5555
```

No Chrome deve aparecer a tela "Estrutura no ar" com o ícone de carteira em verde e a
linha `R$ 1.234,56 · <data de hoje>` — se essa linha aparecer formatada em português,
o intl e o locale pt-BR estão certos.

```bash
git status    # NAO deve listar _local/
claude mcp list   # chrome-devtools e mobile-mcp conectados
```

## Pendências / próximos passos

- **`custom_lint` + `riverpod_lint` ficaram de fora.** A versão atual do `riverpod_lint`
  ainda depende de `riverpod_annotation ^3.x`, e o projeto está no `4.0.7` (exigido pelo
  `flutter_riverpod 3.4.3`). Reavaliar quando o `riverpod_lint` publicar suporte a 4.x.
- **Validar os MCPs de ponta a ponta.** Eles só carregam depois de reiniciar a sessão do
  Claude Code. Detalhes e a ressalva sobre o canvas em `_local/claude/contexto.md`.
- **Bundle id ainda é `com.example.izifc`.** Trocar antes de qualquer build de release.
- **Próxima entrega:** modelagem das tabelas `accounts`, `categories` e `transactions`,
  com repositórios e providers.
