# 0015 — Home com filtros e saldos recolhidos

**Data:** 2026-09-20 · **Status:** ✅ concluído

## O que mudou

Na tela do mês, para ter menos informação empilhada e achar lançamentos rápido:

- **Saldos recolhidos.** O bloco "Saldos hoje" agora abre fechado e mostra só o **total** (uma linha). Um
  toque abre o detalhe (conta a conta e os cartões em aberto), outro fecha. Fica só em memória.
- **Barra de filtros** acima da lista, depois do resumo do mês:
  - **Busca** por texto na descrição e na observação (sem diferenciar maiúscula de minúscula).
  - **Chips de tipo:** Tudo · Despesas · Entradas · Transferências · Faturas.
  - **Botão "Filtrar e ordenar"** (com o número de filtros ligados): abre uma folha para escolher
    **contas e cartões** (várias) e **ordenar** por Data (padrão) ou Valor.
- Com filtro ligado aparece **"Mostrando N de M lançamento(s)"** e o atalho **"Limpar filtros"**.
  Sem resultado: "Nenhum lançamento com esses filtros."
- **Os totais do mês e os saldos não mudam com o filtro:** ele só decide o que a lista mostra.
- Os filtros **voltam ao normal ao trocar de mês**, não são gravados e não sobrevivem ao fechar o app.

## Por quê

A home empilhava saldos, resumo, seletor de mês e lista. O autor pediu um formato de filtros e
deixou a escolha de quais para mim, "tendo em vista a experiência do usuário", para ele testar depois.

- **Escolhi o que já existe nos dados** (tipo, conta/cartão, descrição/observação, valor), sem inventar
  categoria (o app não obriga categoria, por princípio).
- **Transferência e pagamento de fatura aparecem nas duas pontas:** filtrando por uma conta, a
  transferência entra pela origem **e** pelo destino; o pagamento aparece na conta e no cartão.
- **"Tudo" inclui os ajustes de saldo**; cada tipo mostra só o seu.
- **Ordenar não conta como filtro** (não esconde nada): não gera o aviso "Mostrando…" nem o número no botão.
- **Zerar ao trocar de mês** — inclusive quando salvar um lançamento leva a tela para outro mês —, senão um
  filtro esquecido esconderia o lançamento que acabou de ser salvo.
- **Regra no domínio:** `applyFilters` é uma função pura, testada sem interface; ordenar por valor é
  **estável** (empate mantém a ordem de entrada).

## Arquivos tocados

- [`entry_filters.dart`](../lib/features/entries/domain/entry_filters.dart) — `EntryFilters`, `EntryKindFilter`, `EntrySort` e `applyFilters`.
- [`entry_filters_provider.dart`](../lib/features/entries/presentation/entry_filters_provider.dart) — estado em memória.
- [`month_filters.dart`](../lib/features/entries/presentation/month_filters.dart) — barra (busca, botão, chips) e a folha de contas/ordem.
- [`month_screen.dart`](../lib/features/entries/presentation/month_screen.dart) — liga tudo; saldos recolhíveis; aviso "Mostrando".
- Testes: `entry_filters_test` (domínio), `month_filters_test` (tela); `widget_test` ajustado porque os saldos vêm recolhidos.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No app: a home mostra o total recolhido; toque para abrir. Toque em "Despesas": só despesas, com
   "Mostrando N de M", e os totais do mês iguais. Busque "merc": só o que combina. No botão de filtro,
   escolha um cartão e ordene por Valor. Troque de mês: tudo volta ao normal.

## Pendências / próximos passos

- Não filtra por **intervalo de datas** nem por **faixa de valor** (o mês já é o recorte de data).
- ~~A busca não ignora acentos~~ — resolvido na [0016](0016-ux-ui.md).
- Se o bloco de saldos recolhido incomodar quem prefere vê-lo sempre aberto, dá para lembrar a escolha
  (hoje volta recolhido a cada abertura).
- O autor testa e valida o desenho depois; ajustes de layout ficam para a 0016 (identidade visual).
