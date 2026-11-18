# 0047 — Cores de verdade da logo (1.0.4)

**Data:** 2026-11-17 · **Status:** ✅ concluído (o autor ainda vê e ajusta pelas imagens; notas do amigo designer entram aqui)

## O que mudou

- **Paleta por tokens** em [`app_theme.dart`](../lib/core/theme/app_theme.dart): marinho `#1B3A5C` é a cor principal (botões, títulos, links); superfícies em
  **papel quente** no claro e **tinta azul-escura** no escuro (antes lavanda e cinza azulado); **âmbar** `#E8A317` como acento de verdade: o botão +, a
  seleção ativa (tipo de lançamento, contas) e os avisos. O gerador (`fromSeed`) só completa o que não definimos (erro, inversos).
- **Temas de componente**: cartões quentes com borda fina (sem o tom lavanda), barra superior sem tinta, gaveta com indicador âmbar.
- **Alto contraste** reescrito à mão (o gerador deixou de cuidar dele): texto preto ou branco, bordas e erro mais fortes.
- **Trava de contraste** estendida: texto sobre cartão, aviso/seleção âmbar claro e o ícone do botão + sobre o âmbar, nos quatro modos (claro, escuro e os dois de alto contraste).
- Capturas e imagem de destaque (`docs/telas/`) refeitas com o tema novo.

## Por quê

Um amigo designer disse que a cor do app não combinava com a logo (marinho puro com disco âmbar): o tema gerado de uma semente dava lavanda e quase
nenhum âmbar. As cores que mais se veem (botão +, cartão da início, seleção, avisos) agora vêm da marca.

## Como verificar

`flutter test test/core/theme/contrast_test.dart`; ver o app no emulador nos temas claro e escuro (`docs/telas/hero.png`).
