# 0010 — Menu lateral

**Data:** 2026-09-20 · **Status:** ✅ concluído

## O que mudou

- A home, a tela de Contas e cartões e a de Configurações ganharam um **menu lateral**
  (`NavigationDrawer`) com quatro destinos: **Início**, **Contas e cartões**, **Importar
  planilha** e **Configurações**. O item da tela onde se está aparece marcado.
- Os três ícones da barra da home (importar, contas, configurações) **saíram**: viraram itens do
  menu. O botão **+ Novo lançamento** continua onde estava.
- Os destinos de topo (Início, Contas, Configurações) **trocam** a tela (`go`): voltar a partir
  deles sai do app, em vez de empilhar uma tela sobre a outra a cada toque. **Importar planilha**
  **empilha** (`push`) e mantém a seta de voltar, porque é um fluxo em passos que se abandona
  voltando.

## Por quê

O autor achou a home com informação demais e pediu menu lateral. Tirar os ícones da barra
resolve a parte mais barata do problema já; o resto da home (filtros, saldos recolhíveis) é a 0013.

- **`go` nos destinos de topo:** com `push`, ir Início → Contas → Configurações → Contas deixaria
  quatro telas empilhadas, e o "voltar" do sistema percorreria todas. Menu lateral é navegação
  de topo, não histórico.
- **Importar empilha:** é o único destino que é um fluxo (escolher arquivo, aba, mapear, revisar),
  e quem entra por engano quer voltar para onde estava.
- **`current` explícito** no `AppDrawer` em vez de ler a rota: cada tela sabe quem é, e o menu
  não depende de o teste montar o roteador.
- **Teste com texto reduzido:** no `flutter test` todo texto usa a fonte Ahem (cada letra tem a
  largura do corpo) e "Contas e cartões" estouraria os 280 px do menu, o que o Flutter trata como
  erro. O helper [`test/support/menu.dart`](../test/support/menu.dart) reduz o texto só nesses
  testes, com o motivo escrito. Na fonte real cabe: conferido no emulador com o texto em
  "Muito grande". Isso vale como aviso para a 0014, que vai testar todas as telas em vários
  tamanhos: a fonte Ahem gera falso overflow e terá de ser tratada.

## Arquivos tocados

- [`lib/core/widgets/app_drawer.dart`](../lib/core/widgets/app_drawer.dart) — `AppDestination` e `AppDrawer`.
- [`month_screen.dart`](../lib/features/entries/presentation/month_screen.dart), [`accounts_screen.dart`](../lib/features/accounts/presentation/accounts_screen.dart), [`settings_screen.dart`](../lib/features/settings/presentation/settings_screen.dart) — recebem o menu.
- Testes: [`test/core/app_drawer_test.dart`](../test/core/app_drawer_test.dart), helper [`test/support/menu.dart`](../test/support/menu.dart); `general_settings_test` passa a navegar pelo menu.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No emulador: a home tem só o botão de menu na barra; ele lista os quatro destinos; Contas e
   Configurações trocam a tela e o "voltar" sai do app; Importar abre por cima com seta de voltar.
   Repita com o texto em "Muito grande" (Configurações › Geral).

## Pendências / próximos passos

- O botão de voltar do sistema em Contas/Configurações sai do app (por escolha), mas telas
  empilhadas a partir delas (formulário de conta, seções de Configurações) voltam normalmente.
- A 0014 troca o cabeçalho do menu pela logo.
- A tela Importar planilha não tem o menu (é um fluxo); se for preciso, entra na 0013/0014.
