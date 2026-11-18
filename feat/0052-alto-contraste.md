# 0052 — Alto contraste que se vê (1.0.4)

**Data:** 2026-11-18 · **Status:** ✅ concluído

## O que mudou

- **No alto contraste agora a diferença é clara.** Claro: fundo e cartões **brancos**, texto preto, bordas pretas de 2 px (cartões, botões de contorno, tipo de lançamento, campos, divisores), seleção em âmbar forte com texto preto.
  Escuro: fundo **preto**, texto branco, bordas brancas de 2 px, seleção em âmbar escuro com texto branco. O âmbar dos botões continua, com texto escuro (no claro) ou marinho muito escuro.
- Em [`app_theme.dart`](../lib/core/theme/app_theme.dart): os esquemas leem `highContrast` em superfícies, containers, texto e bordas; `CardThemeData`, `DividerThemeData`, `OutlinedButtonThemeData`,
  `SegmentedButtonThemeData` e `InputDecorationTheme` engrossam a borda.
- **Teste novo** em `contrast_test.dart`: no claro e no escuro, o fundo e o cartão **mudam** do normal para o alto contraste, a borda passa de 7:1 contra o fundo e o contorno do cartão vai de 1 para 2 px,
  e o texto é preto ou branco puro (para o "não vi diferença" não voltar).

## Por quê

No celular o autor ligou o alto contraste e disse que não viu diferença. Era verdade: com a paleta nova ele só mudava tons quase iguais (a ligação em `app.dart` estava certa).

## Como verificar

`flutter test test/core/theme/contrast_test.dart`. No emulador: Configurações › Geral › Alto contraste, nos dois temas; comparação em `_local/obsidian/juri/provas/cores/alto-contraste-comparacao.png`.
