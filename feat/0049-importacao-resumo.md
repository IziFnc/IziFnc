# 0049 — Importação em resumo, com "Ver mais detalhes" (1.0.4)

**Data:** 2026-11-17 · **Status:** ✅ concluído

## O que mudou

- **A prévia virou um resumo.** Depois de ligar os nomes, em vez de uma lista com todos os lançamentos, a pessoa vê **um cartão por tipo** (Despesas, Entradas,
  Transferências, Pagamentos de fatura): quantas linhas, quantas marcadas e quanto somam, com **um interruptor** para o grupo inteiro. O que veio desmarcado para
  revisar ganha um aviso destacado, e os **avisos** e as **linhas ignoradas por erro** ficam recolhidos num item só.
- **"Ver mais detalhes"** abre a lista completa, uma linha por vez, agrupada por tipo, para marcar ou desmarcar cada uma. Compartilha o mesmo plano da prévia, então o
  que se muda ali vale ao voltar.
- **Aba sem nenhuma linha legível** (achado F1 da medição com planilhas diferentes): em vez de uma lista vazia com o botão desligado, o app explica o que houve,
  o que conferir (datas de verdade, valor, banco, tipo) e mostra exemplos do que foi descartado.
- Código novo: [`import_summary_card.dart`](../lib/features/import/presentation/import_summary_card.dart) e
  [`import_details_screen.dart`](../lib/features/import/presentation/import_details_screen.dart).

## Por quê

Um amigo designer: "tem muita informação acumulada, dá uma visão de inacabado. Melhor mostrar um resumo e ter um botão de 'ver mais detalhes'".

## Como verificar

`flutter test test/features/import` (cinco testes novos do resumo e um do passo vazio). No emulador: importar `ingles.xlsx` (resumo com 3 cartões) e `data-em-texto.xlsx`
(explicação no lugar do passo vazio).
