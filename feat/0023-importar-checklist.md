# 0023 — Importar: o que precisa antes, no primeiro passo

**Data:** 2026-09-21 · **Status:** ✅ concluído

## O que mudou

O primeiro passo da importação era um botão "Escolher arquivo" numa tela vazia. A falta de chave de IA
(e de contas) só aparecia como erro **depois** de escolher o arquivo e a aba. Agora o passo abre com
**"Antes de começar"**:

- **Contas e cartões cadastrados** — feito (✓) ou pendente, com o atalho **Cadastrar**.
- **Chave de IA configurada** — feito ou pendente, com o atalho **Configurar** (leva a Configurações ›
  Inteligência artificial). Vale a chave guardada no app ou, no desenvolvimento, a do `--dart-define`.
- Dois lembretes fixos: **ajustar o saldo inicial** de cada conta antes da primeira aba (senão o "em
  aberto" dos cartões pode ficar negativo) e o **formato esperado** ("Despesas Gerais" e "Entrada de Valor").
- O botão **"Escolher arquivo" fica desligado** enquanto faltar conta ou IA, com a frase "Faça os itens
  pendentes acima para escolher o arquivo." Ao voltar da tela de IA com a chave salva, o item vira ✓ e o botão liga.

- **Ajuste apontado pelo autor depois:** a importação passa a ser um destino do menu como os outros:
  tem o botão ☰ (não a seta de voltar) e abre com `go`. Antes ela abria por cima da tela de origem e a
  seta voltava para lá (ex.: Contas e cartões), o que parecia um erro. O item fica marcado no menu.

- **Regressão achada no rc.1 (corrigida no rc.2):** ao tornar a importação um destino do menu (`go`), a
  tela anterior deixou de manter vivos `accountsProvider` e `monthStartDayProvider`, que o fluxo lê com
  `.future` ao escolher a aba e ao confirmar. Eles descartam sozinhos, e a leitura falhava com "The provider
  accountsProvider was disposed during loading state" (mostrado como "Não consegui ler essa aba…"). A tela
  agora observa os dois durante todo o fluxo. O seletor de arquivos virou um provider
  (`importFilePickerProvider`) e um teste percorre o fluxo inteiro: arquivo → aba → mapear → prévia → importar.
  Nenhum teste cobria a escolha da aba, por isso a regressão passou.
- **Segunda consequência da mesma mudança (rc.3):** o botão "Voltar para o mês" da tela final usava `pop`,
  que não tem para onde voltar quando a importação é aberta por `go`, então não fazia nada. Achado testando
  o rc.2 no emulador; agora usa `go` para a home, e o teste do fluxo cobre o botão.

## Por quê

Achado P2 da auditoria de UX, escolhido pelo autor: em vez de deixar a pessoa escolher arquivo e aba para só
então esbarrar num erro, o passo diz **o que falta e como resolver**, na hora.

- **Bloquear o botão** (e não só avisar) porque, sem conta ou sem IA, a importação **sempre** falha.
- **`aiConfiguredProvider`** reaproveita `storedSlotsResolver` (a mesma regra da importação de verdade),
  então o checklist não diverge do que a importação usa; recalcula quando a tela de IA salva ou remove.
- A lista rola (`ListView`) para caber em telas pequenas e com texto grande.

## Arquivos tocados

- [`import_screen.dart`](../lib/features/import/presentation/import_screen.dart) — passo 1 e as linhas do checklist.
- [`ai_slots_controller.dart`](../lib/features/settings/presentation/ai_slots_controller.dart) — `aiConfiguredProvider`.
- Testes: `import_checklist_test` (5 cenários); `app_drawer_test` passou a usar o armazenamento de IA em memória.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No app novo (sem chave): ☰ › Importar planilha mostra os itens pendentes e o botão desligado; **Configurar**
   leva à tela de IA; salvar a chave e voltar liga o botão.

## Pendências / próximos passos

- Fecha a frente de UX antes do `rc.1` (só com o "pode" do autor).
- O checklist não confere se o **saldo inicial** já foi ajustado (não há como saber de forma confiável);
  é só um lembrete.
