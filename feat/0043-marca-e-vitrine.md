# 0043 — Marca "Tinta & âmbar", nome novo e vitrine do projeto (1.0.4)

**Data:** 2026-11-16 · **Status:** 🚧 em andamento (tema e teste de contraste prontos; falta nome, ícone, textos e README)

## O que muda

- **Tema "Tinta & âmbar"** ([`app_theme.dart`](../lib/core/theme/app_theme.dart)): marinho `#1B3A5C` como cor principal e âmbar
  `#E8A317` como acento (`tertiary`), com texto **escuro** sobre o âmbar; fundo claro quente `#F7F5EF`. O verde antigo ficava a ΔE 19 do
  teal do WhatsApp.
- **Trava de contraste** ([`contrast_test.dart`](../test/core/theme/contrast_test.dart)): nove pares texto/fundo, nos modos claro, escuro e
  alto contraste, com piso de 4,5:1 (7:1 no alto contraste). A cor deixa de ser gosto e vira regra do CI.
- Nome novo, ícone, capturas, README de estudo de caso e resumo em inglês: entram nesta mesma versão, em PRs seguintes.

## Por quê

Um amigo designer perguntou se o app copiou as cores do WhatsApp; a medida deu ΔE 19,2, zona de semelhança. A decisão da direção, e a do
nome (o prefixo "IZI" tem pedidos de terceiros no INPI), são do autor. O projeto agora é portfólio (caminho A): a marca precisa ser própria.

## Como verificar

`flutter test test/core/theme/contrast_test.dart` e `dart run tool/validar.dart`.
