# 0051 — Mais âmbar: cores v2 (1.0.4)

**Data:** 2026-11-18 · **Status:** ✅ concluído

## O que mudou

- **O âmbar da logo passa a aparecer onde a pessoa toca e no painel**: botões cheios, interruptores e caixas de marcar em âmbar (com o marinho por cima ou ao redor), **moldura âmbar**
  no painel do início, **barra do gasto em âmbar com contorno marinho** e um **fio âmbar** sob a barra superior. Valem no claro e no escuro. O marinho continua nos títulos, links e ícones.
- Temas de componente em [`app_theme.dart`](../lib/core/theme/app_theme.dart) (`FilledButtonThemeData`, `SwitchThemeData`, `CheckboxThemeData`, `AppBarTheme`), em vez de mexer tela por tela.
- **Trava de contraste** estendida: texto do botão cheio (marinho sobre âmbar), bolinha do interruptor, contorno da barra, nos quatro modos. No alto contraste a bolinha e o ícone ficam mais escuros.
- Capturas e imagem de destaque (`docs/telas/`) refeitas.

## Por quê

O autor testou no celular e disse que o que predominava era só o azul, com pouco âmbar. O ensaio mostrou três níveis lado a lado (atual, âmbar nas ações, âmbar nas ações mais faixa), claro e escuro,
em `_local/obsidian/juri/provas/cores/`. Ele escolheu o terceiro.

## Como verificar

`flutter test test/core/theme/contrast_test.dart`. No emulador, comparar com `docs/telas/hero.png`.
