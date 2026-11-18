# 0053 — Passar os meses por gesto (1.0.4)

**Data:** 2026-11-18 · **Status:** ✅ concluído

## O que mudou

- **Arrastar para o lado na tela inicial passa o mês**: para a esquerda vai ao mês seguinte, para a direita volta ([`month_swipe.dart`](../lib/features/entries/presentation/month_swipe.dart)). As setas
  continuam. A troca ganha um esmaecer curto (sem animação com "Remover animações").
- **Para não brigar com o resto:** a rolagem vertical da lista não muda; um arrasto que **começa na borda** (28 dp) é ignorado (o Android usa a esquerda para o menu e as duas para voltar); só vale
  um arrasto deliberado (72 dp com alguma velocidade, ou 160 dp mesmo devagar, para quem arrasta lento); um toque ou deslize curto não troca.
- **Leitor de tela:** a lista ganha as ações "Mês anterior" e "Próximo mês" (além das setas, que seguem com rótulo).

## Por quê

O autor pediu poder passar os meses por gesto, além das setas, e que isso passasse por teste de usabilidade.

## Teste de usabilidade (emulador, adb)

Passou: arrasto para a esquerda e para a direita trocam o mês; rolar na vertical, deslize curto e arrasto da borda esquerda ou direita **não** trocam; mês sem lançamentos e voltar; tocar num lançamento
ainda abre a edição; texto do sistema em 180% (o gesto e a lista continuam). **Não feito:** júri de agentes sobre descoberta do gesto (agente não faz gesto) e TalkBack no aparelho. A pista
("existe o gesto?") fica para o autor avaliar no celular (roteiro F01 a F04).

## Como verificar

`flutter test test/features/entries/month_swipe_test.dart` (sete testes) e o grupo "passar os meses por gesto" em `month_filters_test.dart`.
