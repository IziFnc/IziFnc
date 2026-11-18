# 0046 — Guia: foco que fecha sem sustos (1.0.4)

**Data:** 2026-11-17 · **Status:** ✅ concluído

## O que mudou

- **Abrir e fechar mais curtos** (350 ms e 200 ms, antes 600 ms cada): o recorte que cresce até sumir parecia lento e desigual para alvos fora do centro (o botão +).
- **Só o primeiro toque na bolha vale**: "Próximo" duas vezes, ou "Pular" logo depois de "Próximo", cortava a animação ou avançava dois passos.
- **Voltar do Android bloqueado com a bolha aberta**: antes fechava a tela por baixo e deixava o véu parado no lugar antigo. A saída é "Próximo" ou "Pular".
- **O alvo só é medido depois da transição de rota** (o recorte não fica fora de lugar nos passos que abrem outra tela).
- **Respeita "Remover animações"** do Android (o pacote ignora; agora as durações caem para 1 ms).

## Por quê

O autor notou animações de foco estranhas no fechamento do guia. O guia usa o pacote `tutorial_coach_mark` (overlay, sem rota); a leitura do código dele
mostrou o fechamento de 600 ms com recorte que cresce, a ausência de trava de toque e o voltar sem tratamento.

## Como verificar

`flutter test test/core/tour_test.dart` (três testes novos: toque duplo, voltar bloqueado e "Próximo" depois do voltar). No emulador: Configurações › Geral › Ver o
tour de novo; tocar duas vezes em "Próximo" avança um passo só; apertar voltar não derruba a tela.

## Não verificado

Sem vídeo comparativo antes/depois. Observação no emulador: um toque em "Próximo" dado nos primeiros 2 s depois de apertar voltar (enquanto o aviso "Toque em
voltar de novo para sair" da home está na tela) foi ignorado; passados 2 s funciona. Impacto baixo; fica anotado.
