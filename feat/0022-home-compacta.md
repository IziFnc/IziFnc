# 0022 — Home compacta: o topo cabe em ~20% da tela

**Data:** 2026-09-21 · **Status:** ✅ concluído

## O que mudou

O topo da home ocupava quase metade da tela (saldos, seletor de mês, resumo, campo de busca e chips de
tipo, empilhados antes do primeiro lançamento). Agora:

- **Barra:** `☰  ‹ Setembro de 2026 ›  🔍  ⚙` — o mês (com as setas) e as ações vão para a barra. A lupa
  troca o título por um campo de busca; o botão de filtro mostra o número de filtros ligados.
- **Um cartão de situação** de 2–3 linhas: "Em conta", "Faturas abertas" (só se houver) e
  "Entrou … · Gastou …". Tocar abre uma **folha de detalhes**: cada conta (saldo de hoje), cada fatura
  aberta e o resumo do mês (Entradas, Gastos no débito, Gastos no cartão X). Tocar numa conta ou fatura da
  folha **filtra a lista** por ela.
- **Folha "Filtrar e ordenar"** ganhou a seção **Tipo** (Tudo/Despesas/Entradas/Transferências/Faturas):
  os chips saíram da home.
- **Valores da lista** no tamanho do nome do lançamento, em negrito leve (eram ~11 sp).
- **Primeiros passos:** com conta cadastrada e nenhum lançamento, a home mostra um guia (ajustar saldo,
  cadastrar cartão, importar a planilha, lançar o primeiro gasto) no lugar do "Nenhum lançamento". Some
  sozinho no primeiro lançamento.
- **Aviso de backup:** faixa de uma linha, dispensável, quando o backup passou de 30 dias, ou quando nunca
  foi feito e já há 10 ou mais lançamentos. "Salvar" leva a Configurações › Dados.

## Por quê

Resultado da auditoria de UX (achados H1–H5, P1 e S3) e do pedido do autor de reduzir o espaço do topo
("quase 50% da tela… reduzir informações ou dividir em mais telas"). O desenho foi aprovado antes de codar
(a primeira versão ainda ocupava muito; a segunda, compacta, foi a aprovada).

- **Sem ambiguidade nos números:** o "Cartão Amazon R$ 219,89" (gasto do mês) e o "em aberto R$ 89,90"
  (dívida hoje) tinham o mesmo nome; agora "Gastos no cartão Amazon" (resumo do mês) e "Faturas abertas"
  (o que se deve) são coisas com nomes diferentes.
- **A fatura em aberto é o dado mais urgente do cartão**, e agora aparece de relance no cartão, sem abrir nada.
- **Linhas de saldo de 48 dp:** as antigas linhas de saldo (28–34 dp) eram pequenas demais para o toque; na
  folha, cada linha tem ao menos 48 dp (a exceção de acessibilidade conhecida saiu do teste).
- **Só o texto do mês encolhe** na barra quando falta espaço; as setas mantêm 48 dp.
- **Regra pura testada:** `MonthSituation` (domínio) junta saldos e resumo; um cartão com crédito não abate a
  fatura de outro.
- **Primeiros passos sem coluna nova:** "nunca lançou nada" vem da contagem de lançamentos, então não há
  migração; o aviso de backup dispensado vale só até fechar o app (se continuar vencido, volta).

## Arquivos tocados

- [`month_screen.dart`](../lib/features/entries/presentation/month_screen.dart) — barra, corpo, lista.
- [`month_situation_widgets.dart`](../lib/features/entries/presentation/month_situation_widgets.dart) — cartão, folha, primeiros passos, aviso de backup.
- [`month_filters.dart`](../lib/features/entries/presentation/month_filters.dart) — botão, campo de busca e folha com Tipo.
- [`month_situation.dart`](../lib/features/entries/domain/month_situation.dart) — regra pura.
- `entries_repository.dart` (`watchCount`), `month_providers.dart` (`entryCount`, `BackupNoticeDismissed`).
- Testes: `month_situation_test`, `home_notices_test`, `month_filters_test` e `widget_test` adaptados; a matriz de
  telas ganhou "situação (folha)" e "busca aberta" e ficou sem exceções de acessibilidade.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No app: a lista de lançamentos aparece logo abaixo do cartão de situação; toque no cartão (detalhes) e
   numa conta da folha (filtra); lupa busca; ⚙ filtra por tipo, conta e ordem.

## Pendências / próximos passos

- **0023** checklist da importação. Depois, o `rc.1` (só com o "pode").
- Fora do escopo escolhido: sinal de rolagem nos chips, botão "Lançar" no mês vazio, "Conta ou cartão" no lugar
  de "Onde", saldo por linha em Contas e cartões.
- A seta "→" das transferências aparece como quadrado na captura de teste; conferir no aparelho.
