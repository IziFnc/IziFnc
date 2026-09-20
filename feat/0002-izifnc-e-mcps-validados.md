# 0002 — Rename para IziFnc e MCPs validados

**Data:** 2026-09-13 · **Status:** ✅ concluído

## O que mudou

**Nome e identidade do app**

| O quê | Antes | Agora |
|---|---|---|
| Nome exibido (celular, web, AppBar) | `izifc` / `IziFc` | `IziFnc` |
| Bundle id (`applicationId` e `namespace`) | `com.example.izifc` | `com.getulio.izifnc` |
| Pacote Dart | `izifc` | `izifnc` (imports viraram `package:izifnc/...`) |
| Pacote Kotlin do `MainActivity` | `com.example.izifc` | `com.getulio.izifnc` |
| Arquivo do banco Drift | `izifc` | `izifnc` |
| Classe raiz | `IziFcApp` | `IziFncApp` |

A pasta do repositório continua `IziFc`. Renomear ou não fica a critério do autor.

**MCPs de teste visual, testados de ponta a ponta**

- `chrome-devtools`: abriu o app, emulou viewport de celular 393×852, tirou screenshot e
  leu o console (sem erros).
- `mobile-mcp`: estava quebrado no Windows. Foi corrigido no [`.mcp.json`](../.mcp.json)
  e validado chamando uma ferramenta pelo protocolo MCP.

## Por quê

**IziFnc.** É o nome escolhido pelo autor, um trocadilho com "finanças izi". O pacote Dart
foi renomeado junto, apesar de ser invisível para o usuário: hoje isso tocava 6 arquivos,
mais tarde tocaria todos os imports do app. Sem o rename, o nome interno e o de produto
ficariam diferentes para sempre.

**`com.getulio.izifnc`.** A Play Store rejeita qualquer app com `com.example` e só exige
que o id seja único, não que você seja dono de um domínio. Nome próprio + app é a
convenção de dev solo e serve para apps futuros (`com.getulio.<app>`). **Esse id não pode
mudar depois de publicar:** um id novo é um app novo, e quem já instalou perde os dados
locais. Deixei um comentário avisando isso no `build.gradle.kts`.

**Correção do `mobile-mcp`.** O `mobile-mcp` chama um binário auxiliar, o `mobilecli`.
O pacote `mobilecli` declara como dependência só a variante Linux
(`@mobilenext/mobilecli-linux-amd64`), e no Windows o `mobile-mcp` procura
`mobilecli-windows-amd64.exe`, que nunca é instalado. O resultado era o erro
"mobilecli is not available". A correção pede ao `npx` os dois pacotes na mesma
instalação (`-p mobile-mcp -p mobilecli-windows-amd64`), e aí o binário cai no caminho
que o `mobile-mcp` procura. Descartei a alternativa de usar a variável `MOBILECLI_PATH`
porque ela exigiria um caminho absoluto desta máquina dentro de um arquivo versionado.

**A ressalva do canvas caiu.** A `0001` registrou que, no Flutter web, o MCP só
conseguiria interagir por coordenada. Isso não é verdade: clicar no elemento escondido
`flt-semantics-placeholder` ativa a árvore de acessibilidade do Flutter, e o MCP passa a
enxergar cada widget com um `uid`. Isso foi testado: o snapshot listou o título, os
textos e o valor em reais. O passo a passo está no [README](../README.md#testes-visuais-com-mcp).

## Arquivos tocados

- [`android/app/build.gradle.kts`](../android/app/build.gradle.kts): `namespace` e `applicationId`
- `android/app/src/main/kotlin/com/example/izifc/MainActivity.kt` →
  [`com/getulio/izifnc/MainActivity.kt`](../android/app/src/main/kotlin/com/getulio/izifnc/MainActivity.kt)
- [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml): `android:label`
- [`pubspec.yaml`](../pubspec.yaml): `name` e `description`
- `lib/`: `main.dart`, `app.dart`, `dashboard_screen.dart`, `app_database.dart`, `app_theme.dart`
- [`test/widget_test.dart`](../test/widget_test.dart): imports e texto esperado
- [`web/index.html`](../web/index.html), [`web/manifest.json`](../web/manifest.json)
- [`.mcp.json`](../.mcp.json): comando do `mobile-mcp`
- [`README.md`](../README.md): nome e seção de MCP reescrita

## Como verificar

```bash
flutter analyze            # No issues found!
flutter test               # All tests passed! (3 testes)
git grep -i izifc -- . ":!feat/0001-reestruturacao-base.md" ":!*.g.dart"   # nada
```

**Android:** `flutter emulators --launch Pixel_9` e depois `flutter run`. O app abre com
"IziFnc" na barra, e o log mostra `com.getulio.izifnc.MainActivity`.

**Web + MCP:** `flutter run -d web-server --web-port=5555`, abrir `localhost:5555` pelo
`chrome-devtools`, emular `393x852x3,mobile,touch`, rodar o script de semântica e tirar
um `take_snapshot`. O snapshot deve listar "IziFnc", "Estrutura no ar" e
"R$ 1.234,56 · <data>".

**`mobile-mcp`:** numa sessão nova do Claude Code, com o emulador ligado, chamar
`mobile_list_available_devices`. Deve aparecer o Pixel 9.

## Pendências / próximos passos

- **Aprovar o `mobile-mcp` de novo.** Mudar o comando dele no `.mcp.json` desfaz a
  aprovação anterior. Na próxima sessão, o Claude Code vai pedir para aprovar. Até lá,
  esta sessão continua rodando a versão antiga (quebrada).
- **A `0001` fica como está.** Ela descreve o projeto quando ainda se chamava IziFc e
  registra a ressalva do canvas que depois caiu. É histórico: não se reescreve, se corrige
  numa entrada nova, como esta.
- **Próxima entrega:** modelagem de dados a partir da planilha do autor. Antes, há
  perguntas de modelo a responder com ele (ver `_local/claude/analise-planilha.md`).
