# 0026 — Guia dentro do app: tour guiado, tela por tela

**Data:** 2026-09-23/24 · **Status:** ✅ concluído

## O que mudou

Na primeira vez que a pessoa usa o app, um tour guiado anda sozinho por sete paradas,
mostrando as funções principais uma de cada vez: a tela escurece, um recorte destaca o botão
certo e um cartão explica o que ele faz, com um contador ("2 de 7") e um botão para seguir —
que já leva para a próxima tela, quando for o caso.

1. **Cadastrar a primeira conta** — na home vazia; o botão da bolha faz a mesma coisa que o
   botão real (leva ao formulário).
2. **Situação de relance** — o cartão de saldo/faturas da home.
3. **Busca e filtros** — a barra da home.
4. **Escolher o tipo do lançamento** — a grade (menciona "Pagar fatura" no texto).
5. **Escolher o arquivo da planilha** — mostra mesmo com o botão desligado (sem chave de IA
   configurada ainda): senão o tour travaria aqui para sempre.
6. **Menu de Configurações**.
7. **Backup**, dentro de Configurações › Dados — último passo, botão "Concluir".

Dá para **pular o tour inteiro** a qualquer momento (botão "Pular o tour" em toda bolha) e
**revê-lo depois** por "Ver o tour de novo", em Configurações › Geral — quem já tem conta
cadastrada cai direto na 2ª parada (a 1ª não existe mais numa home com contas).

## Por quê

Pedido do autor, em duas rodadas depois de ver a primeira versão funcionando:

- **V1 (mesmo dia, nunca publicada):** quatro dicas **independentes**, cada uma disparando
  sozinha na primeira vez que a pessoa chegava naquela tela por conta própria. O autor achou
  "cru" (só texto solto sobre o véu, sem cartão/ícone) e pediu uma bolha de verdade com "N de
  M", **e** o tour andando sozinho de tela em tela, cobrindo mais funções — não só esperando a
  pessoa esbarrar em cada botão. Como nada da v1 tinha sido commitado, esta entrega
  **substituiu** o mecanismo dela (`TourHint`/`CoachMarkOnce`/bitmask) em vez de empilhar em
  cima, inclusive reaproveitando a mesma migração de schema (v7→v8) com uma coluna diferente.
- **Sequência, não bits independentes:** `app_settings.tour_step` guarda **um número** (a
  próxima parada), não mais um bit por dica — o tour é uma ordem fixa (`kTourSteps`), então um
  índice basta; simplifica a lógica de "qual tela mostra o quê" para "sou eu agora?".
- **O botão da bolha decide a navegação** (`TourStep.nextRoute`/`pushNext`): nenhuma tela
  precisa saber que está no meio de um tour, só reagir se o índice bate com o próprio
  `TourAnchor`. `push` quando a próxima parada é uma tela que se volta de verdade (o formulário
  de conta — sem ele não tem como criar a conta —, e Dados como sub-tela de Configurações);
  `go` nos outros.
- **`ContentAlign` por passo, não fixo:** o pacote precisa saber de que lado da tela colocar a
  bolha para não estourar. Alvos perto do topo (situação, filtros, grade de tipos) usam
  "abaixo" (o padrão); alvos mais para baixo na tela (escolher arquivo, depois de um checklist
  comprido) usam "acima". Descoberto testando: sem isso a bolha nasce fora da tela e nenhum
  toque nela funciona.
- **"Escolher arquivo" mostra mesmo desabilitado:** diferente de outras dicas, esta parada é
  uma etapa **obrigatória** de uma sequência — se ficasse esperando a chave de IA (algo que o
  tour não pede para configurar), o passeio travaria para sempre aqui. A dica é educativa
  ("é aqui que se importa, quando tiver a chave"), não um apontador do que já dá pra usar.
- **Sem um alvo aninhado dentro de outro:** a ideia original tinha um passo próprio para o
  chip "Pagar fatura", dentro do mesmo `TourTarget` da grade inteira. Dois `TutorialCoachMark`
  encadeados na mesma tela (um saindo, o outro entrando) travava a suíte de teste
  (`pumpAndSettle` nunca assentava) — a informação sobre "Pagar fatura" virou parte do texto
  do passo da grade, sem precisar de um recorte à parte.
- **Configurações destaca só a 1ª seção, não a lista inteira:** a lista de seções ocupa a tela
  toda, sem sobra de espaço acima nem abaixo — a bolha não tinha onde caber. Só o primeiro
  item ("Geral") vira o alvo.
- **`pulseEnable: false`** continua (pulso contínuo nunca "assenta", travaria os testes) e
  **`tourEnabledProvider`** desliga o recurso nos testes que só passam pelas telas afetadas,
  sem testar o tour em si (o véu é modal, bloqueia toque).

## Correções do teste no celular real (rc.6, 2026-09-24)

O rc.5 foi instalado no celular do autor (Samsung SM-S721B) e o emulador não tinha mostrado
três problemas:

- **`ContentAlign.top` estourava a barra de status:** no passo do backup, a bolha é mais alta
  num aparelho real (fonte do sistema, barra de status) do que no emulador — nasceu colada no
  topo e ficou atrás do relógio/bateria. Lição: só usar `ContentAlign.top` quando o espaço
  **acima** do alvo é claramente maior que a bolha (ex.: o passo da importação, depois de um
  checklist comprido); nos outros casos, `ContentAlign.bottom` (o padrão) tem mais margem de
  segurança porque o rodapé da tela costuma sobrar mais espaço que o topo.
- **Alvo incompleto no passo de busca/filtro:** só o botão de filtro era destacado, mas o
  texto também falava da lupa — virou um `TourTarget` só, envolvendo os dois botões (busca/
  fechar busca e filtro) num `Row`. A troca de ícone (buscar ↔ fechar busca) acontece dentro do
  mesmo alvo, então não gera o problema de "alvo instável" que tinha afastado a lupa na v2.
- **Teclado cobrindo a bolha:** o campo "Valor" do lançamento tem foco automático
  (`autofocus`), que abre o teclado por cima dos botões da bolha no passo da grade de tipos.
  Corrigido em duas camadas: o campo não recebe foco automático quando a tela é a parada atual
  do tour, e `TourTarget._show` chama `FocusManager.instance.primaryFocus?.unfocus()` como
  rede de segurança geral, antes de abrir qualquer bolha.
- **Um "SKIP" solto por cima do FAB:** o `tutorial_coach_mark` desenha, por padrão, o próprio
  texto de pular (`textSkip = "SKIP"`, canto inferior direito) além de qualquer conteúdo do
  `builder` — como a bolha já tem "Pular o tour", esse texto ficava sobrando exatamente em
  cima do botão flutuante da tela (visível já na primeira parada). Corrigido com
  `hideSkip: true` no `TutorialCoachMark`.
- **Véu escuro demais no tema escuro:** o pacote dimeriza o que não é o alvo com um véu preto a
  80% (`opacityShadow`, padrão do pacote); sobre um fundo já quase preto do tema escuro, isso
  deixava o texto ao redor do botão destacado ilegível (a régua de contraste só funciona
  porque no tema claro o fundo dimmed ainda sobra brilho). Corrigido com
  `opacityShadow: 0.45` quando `Theme.of(context).brightness == Brightness.dark` (mantém 0.8 no
  claro).
- **Bolha estourando a borda de baixo (passo 1):** o pacote posiciona a bolha `ContentAlign.bottom`
  crescendo para baixo do alvo, sem checar se sobra espaço — no passo de cadastrar a primeira
  conta, o botão fica no meio da tela vazia, e a bolha acabava encostando (ou quase saindo) na
  borda inferior. Mesma lição do passo do backup (agora com `ContentAlign.top`, que tem mais
  espaço livre acima nesta tela).

Também revisado o texto de todas as paradas (clareza e consistência do português).

## Arquivos tocados

- `lib/core/widgets/tour_step.dart` — `TourAnchor` (enum, um valor por parada — o índice é o
  número persistido), `TourStep` (o que mostrar e como navegar) e `kTourSteps` (o roteiro).
- `lib/core/widgets/tour_bubble.dart` — o cartão visual (ícone, "N de M", título, mensagem,
  "Pular o tour" e o botão de seguir).
- `lib/core/widgets/tour_target.dart` — o widget que embrulha cada alvo (substitui o
  `CoachMarkOnce`/`TourHint` da v1, removidos).
- `lib/features/settings/data/settings_table.dart` — coluna `tourStep` (schema v8, no lugar do
  `tourHintsSeen` da v1).
- `lib/features/settings/data/settings_repository.dart` — `watchTourStep`/`advanceTour`/
  `skipTour`/`restartTour` (este último pula a 1ª parada se já houver conta).
- `lib/features/entries/presentation/month_screen.dart` (`_NoAccounts`, `SituationCard`,
  `FilterButton`), `lib/features/accounts/presentation/accounts_screen.dart`,
  `lib/features/entries/presentation/entry_form_screen.dart`,
  `lib/features/import/presentation/import_screen.dart`,
  `lib/features/settings/presentation/settings_screen.dart`,
  `lib/features/settings/presentation/data_settings_screen.dart` — `TourTarget` nos alvos.
- `lib/features/settings/presentation/general_settings_screen.dart` — "Ver o tour de novo".
- `test/core/tour_test.dart` (substitui `coach_mark_test.dart` da v1) — percorre as 7 paradas
  até "Concluir", "Pular o tour" encerra tudo, e "Ver o tour de novo" com conta já cadastrada
  pula a 1ª parada.

## Como verificar

1. `dart run drift_dev make-migrations`, `flutter analyze`, `flutter test`.
2. `test/core/tour_test.dart` cobre o fluxo completo (ver acima).
3. No emulador (`mobile-mcp`, `Pixel_9`), instalação nova: o tour abre sozinho na home vazia e
   anda até o fim; a bolha (ícone, "N de 7", cartão com fundo) cabe na tela em cada parada, nos
   temas claro/escuro; "Ver o tour de novo" em Configurações traz de volta.

## Pendências / próximos passos

- Sem retomar de onde parou se o app fechar no meio do tour (decisão do autor: simplicidade;
  "Ver o tour de novo" resolve para quem quiser rever).
- Mais uma parada no futuro: só um `TourAnchor` novo, uma entrada em `kTourSteps` e embrulhar o
  alvo com `TourTarget` — nenhuma peça nova. Cuidado com o `ContentAlign` (testar se cabe).
