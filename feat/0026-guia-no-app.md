# 0026 — Guia dentro do app: tour guiado, tela por tela

**Data:** 2026-09-23/24, correções 2026-09-25/26 · **Status:** ✅ concluído

## O que mudou

Na primeira vez que a pessoa usa o app, um tour guiado anda sozinho por oito paradas,
mostrando as funções principais uma de cada vez: a tela escurece, um recorte destaca o botão
certo e um cartão explica o que ele faz, com um contador ("2 de 8") e um botão para seguir —
que já leva para a próxima tela, quando for o caso.

1. **Cadastrar a primeira conta** — na home vazia; o botão da bolha faz a mesma coisa que o
   botão real (leva ao formulário).
2. **Cadastrar um cartão** (se usar) — aponta pro item do `FirstStepsCard` na home, com "Cartão"
   já pré-selecionado no formulário; quem não usa cartão volta sem salvar e segue em frente.
3. **Situação de relance** — o cartão de saldo/faturas da home.
4. **Busca e filtros** — a barra da home.
5. **Escolher o tipo do lançamento** — a grade (menciona "Pagar fatura" no texto).
6. **Escolher o arquivo da planilha** — mostra mesmo com o botão desligado (sem chave de IA
   configurada ainda): senão o tour travaria aqui para sempre.
7. **Menu de Configurações**.
8. **Backup**, dentro de Configurações › Dados — último passo, botão "Concluir".

Dá para **pular o tour inteiro** a qualquer momento (botão "Pular o tour" em toda bolha) e
**revê-lo depois** por "Ver o tour de novo", em Configurações › Geral — quem já tem conta
cadastrada pula a 1ª parada, e quem já tem conta e cartão pula direto pra 3ª (situação).

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

## Correção 2: passo do cartão separado do passo da conta (2026-09-26)

Um amigo testando o rc.6 seguiu o tour, cadastrou a conta do banco e, ao voltar pra home, "se
sentiu jogado numa tela" — nada indicava que faltava cadastrar um cartão também antes do resto
do tour fazer sentido ("Pagar fatura" só existe com cartão). O passo 1 tentava explicar conta e
cartão juntos, mas só levava à criação de uma conta (tipo padrão do formulário).

- **Novo `TourAnchor.cardAdd`**, logo depois de `accountsAdd` (desloca os demais um índice —
  7 paradas viraram 8). Aponta pro item "Cadastrar um cartão" que **já existia** no
  `FirstStepsCard` da home (aparece assim que a primeira conta é criada, some sozinho quando já
  há cartão) — nenhuma navegação nova precisou ser inventada.
- **`TourStep` ganhou `extra`** (repassado no `context.push`/`go`): o botão da bolha do novo
  passo abre o formulário já com "Cartão" pré-selecionado (`AccountFormScreen.initialKind`,
  também aproveitado pelo próprio item do `FirstStepsCard` fora do tour).
- **`restartTour()`** passou a checar conta **e** cartão: pula pra `cardAdd` se só falta o
  cartão, pula direto pra `situationCard` se já há os dois.
- **Achado ao testar a inserção do passo novo:** a bolha da parada seguinte (`situationCard`)
  tentava aparecer **por cima do formulário recém-empilhado** (`push`) assim que a pessoa tocava
  "Cadastrar cartão" — porque a home, ainda montada por baixo do formulário, já enxergava o
  índice do tour avançado e tentava mostrar sua bolha na hora, antes do formulário assentar.
  Isso não acontecia entre `accountsAdd`→`cardAdd` (a home ainda estava no estado "sem contas",
  sem alvo pronto), mas acontecia aqui porque a home já tinha tudo pronto. Corrigido de forma
  geral (não só para este caso): `TourTarget` agora observa a própria rota via `RouteObserver`
  (`tourRouteObserver`, registrado no `GoRouter`) e só mostra a bolha quando a rota está
  **em primeiro plano** (`ModalRoute.isCurrent`); ao voltar de uma tela empilhada por cima
  (`didPopNext`), tenta de novo. Protege qualquer inserção futura de parada do mesmo problema.

## Correção 2.1: segunda chamada fantasma do `onFinish` travava o toque seguinte (2026-09-26)

Achado depurando um sintoma esquisito ao vivo (celular real e emulador): depois de tocar
"Cadastrar cartão" e cair no formulário, alguns toques simplesmente paravam de funcionar (o
chip da conta dona não marcava, um campo não ganhava foco), sem nenhum erro visível na tela.
Rodando `flutter run` conectado ao aparelho, o console mostrou a causa: uma exceção não tratada
(`Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe`).

O `tutorial_coach_mark` acompanha a posição do alvo quadro a quadro durante a animação de saída;
quando o alvo (o botão "Cadastrar conta") some da tela no meio dessa animação, porque a conta
foi salva e a home trocou de corpo, o pacote não acha mais o alvo, cai no próprio mecanismo de
"pular pro próximo" e chama `onFinish` **de novo**, sozinho, um tempo depois. Como a nossa
`_advance()` já tinha rodado uma vez (avançando o índice e navegando), essa segunda chamada caía
numa instância de `TourTarget` já desmontada e usava `ref` de um jeito que o Riverpod rejeita —
a exceção não tratada, ocorrendo durante o processamento de um gesto, deixava a interação
seguinte instável.

Corrigido com uma trava simples: `_show()` guarda um `finished` local (por chamada, não pelo
`_open` da instância) e `onFinish`/`onSkip` só têm efeito na primeira vez. Confirmado ao vivo,
com `flutter run` no celular: a mensagem "Failed to refresh target position" ainda aparece no
console (o pacote continua tentando), mas sem mais exceção, e o chip da conta dona volta a
marcar normalmente.

## Correção 3: dois gestos de voltar para sair (2026-09-26)

Achado testando a correção acima: os destinos do menu lateral (`AppDrawer`, feature 0010)
trocam de tela com `context.go` (sem empilhar) — "voltar" a partir de qualquer um deles já
fechava o app com um único gesto, de propósito (documentado desde a 0010). O tour, ao levar a
pessoa direto pra Importar planilha ou Configurações logo no início do uso, tornava esse
comportamento mais fácil de disparar sem querer.

- **`lib/core/widgets/double_back_to_exit.dart`** (novo): embrulha um destino do menu — quando
  a tela não tem pra onde voltar (`!Navigator.canPop`), o primeiro gesto de voltar mostra
  "Toque voltar de novo para sair" e só o segundo, dentro de 2s, fecha de verdade
  (`SystemNavigator.pop()`). Quando a tela **tem** pra onde voltar (empilhada de verdade, ex.:
  formulário aberto por cima), não interfere — o gesto normal já funciona.
- Aplicado às 4 telas do menu: `MonthScreen`, `AccountsScreen`, `ImportScreen`,
  `SettingsScreen`.

## Arquivos tocados

- `lib/core/widgets/tour_step.dart` — `TourAnchor` (enum, um valor por parada — o índice é o
  número persistido), `TourStep` (o que mostrar, `extra` e como navegar) e `kTourSteps` (o
  roteiro, 8 paradas).
- `lib/core/widgets/tour_bubble.dart` — o cartão visual (ícone, "N de M", título, mensagem,
  "Pular o tour" e o botão de seguir).
- `lib/core/widgets/tour_target.dart` — o widget que embrulha cada alvo; observa a própria rota
  via `tourRouteObserver` (`RouteObserver`) pra só mostrar a bolha em primeiro plano.
- `lib/core/widgets/double_back_to_exit.dart` — dois gestos de voltar pra sair, nas telas do
  menu lateral.
- `lib/core/router/app_router.dart` — registra `tourRouteObserver`; `AccountFormScreen.newPath`
  repassa `extra` como `initialKind`.
- `lib/features/accounts/presentation/account_form_screen.dart` — `initialKind` (pré-seleciona
  "Cartão" quando vem do tour ou do `FirstStepsCard`).
- `lib/features/settings/data/settings_table.dart` — coluna `tourStep` (schema v8, no lugar do
  `tourHintsSeen` da v1).
- `lib/features/settings/data/settings_repository.dart` — `watchTourStep`/`advanceTour`/
  `skipTour`/`restartTour` (este último considera conta e cartão pra decidir onde recomeçar).
- `lib/features/entries/presentation/month_screen.dart` (`_NoAccounts`, `SituationCard`,
  `FilterButton`, `DoubleBackToExit`),
  `lib/features/entries/presentation/month_situation_widgets.dart` (`FirstStepsCard`,
  `TourTarget(cardAdd)`), `lib/features/accounts/presentation/accounts_screen.dart`,
  `lib/features/entries/presentation/entry_form_screen.dart`,
  `lib/features/import/presentation/import_screen.dart`,
  `lib/features/settings/presentation/settings_screen.dart`,
  `lib/features/settings/presentation/data_settings_screen.dart` — `TourTarget` nos alvos
  (e `DoubleBackToExit` nas 4 telas do menu).
- `lib/features/settings/presentation/general_settings_screen.dart` — "Ver o tour de novo".
- `test/core/tour_test.dart` (substitui `coach_mark_test.dart` da v1) — percorre as 8 paradas
  até "Concluir" (inclusive cadastrando um cartão de verdade no passo novo), "Pular o tour"
  encerra tudo, e "Ver o tour de novo" cobre os três casos de recomeço (sem conta, com conta
  sem cartão, com conta e cartão).

## Como verificar

1. `dart run drift_dev make-migrations`, `flutter analyze`, `flutter test`.
2. `test/core/tour_test.dart` cobre o fluxo completo (ver acima).
3. No emulador ou celular real (`mobile-mcp`), instalação nova: o tour abre sozinho na home
   vazia e anda até o fim, inclusive cadastrando um cartão no passo novo; a bolha (ícone, "N de
   8", cartão com fundo) cabe na tela em cada parada, nos temas claro/escuro; "Ver o tour de
   novo" em Configurações traz de volta, pulando as paradas cujo alvo já não existe mais.
4. Sair de qualquer uma das 4 telas do menu (Início, Contas e cartões, Importar planilha,
   Configurações) com o gesto de voltar: o primeiro gesto mostra o aviso, só o segundo (dentro
   de 2s) fecha o app.

## Pendências / próximos passos

- Sem retomar de onde parou se o app fechar no meio do tour (decisão do autor: simplicidade;
  "Ver o tour de novo" resolve para quem quiser rever).
- Mais uma parada no futuro: só um `TourAnchor` novo, uma entrada em `kTourSteps` e embrulhar o
  alvo com `TourTarget` — nenhuma peça nova. Cuidado com o `ContentAlign` (testar se cabe).
