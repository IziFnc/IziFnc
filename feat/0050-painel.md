# 0050 — Painel na tela inicial (1.0.4)

**Data:** 2026-11-17 · **Status:** ✅ concluído

## O que mudou

- **O cartão de números da home virou um painel** ([`month_panel_card.dart`](../lib/features/entries/presentation/month_panel_card.dart)): "Em conta" (com o olhinho), **uma barra**
  que mostra o quanto do que entrou já foi gasto ("Gastou 38% do que entrou"; a barra inteira é o que entrou) e uma linha com o **vencimento de cartão mais próximo**
  ("Cartão Roxo vence em 18 dias"). Com os valores à vista aparece também "Entrou R$ x · Gastou R$ y". Tocar abre a Situação.
- **Funciona sem os valores em reais** (o olhinho os esconde ao abrir o app): a barra, o percentual e os dias não dependem deles. Gastar mais do que entrou enche a barra
  com a cor de erro **e** ganha ícone e a frase "Gastou acima do que entrou" (nunca só cor). Sem entradas no mês, a frase diz isso em vez de dividir por zero.
- **Leitor de tela:** o painel fala "Em conta, valor oculto. Gastou 38% do que entrou. Cartão Roxo vence em 18 dias. Toque para ver a situação" (sem ler os reais escondidos);
  o olhinho fica fora da área tocável para o leitor de tela alcançá-lo. Texto grande: a barra é de largura inteira e a frase quebra.
- Domínio puro em [`month_panel.dart`](../lib/features/entries/domain/month_panel.dart) (percentual, estouro, vencimento mais próximo), testado. O `SituationCard` antigo saiu;
  "Faturas abertas" fica na Situação.

## Por quê

O amigo designer disse que a home tinha números demais. O primeiro uso do modo **Ateliê com teste dos cinco segundos** ([[2026-11-painel-inicio]]) comparou três propostas com
cinco personas e escolheu a B enxuta. Depois o autor reparou que a barra "Entrou" **sempre dá 100%** (é só a régua) e que isso só ocupava espaço: virou uma barra só.

## Como verificar

`flutter test test/features/entries/month_panel_test.dart` (domínio e tela: escondido, visível, estouro, toque, leitor de tela, texto 200%). No emulador: o painel da home abre com
"R$ ••••", a frase e a barra; o olho mostra os valores; tocar leva à Situação. Imagens em `docs/telas/`.

## Não verificado

Teste com pessoas de verdade (as personas eram IA). Sem teste de TalkBack no aparelho; a frase falada só foi conferida pela árvore de semântica do teste.
