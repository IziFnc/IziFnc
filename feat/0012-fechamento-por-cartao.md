# 0012 — Regra do dia do fechamento, por cartão

**Data:** 2026-09-20 · **Status:** ✅ concluído

## O que mudou

- Cada **cartão** passa a ter uma escolha: a compra feita **no próprio dia do fechamento** entra na
  **fatura atual** ou na **próxima fatura**. A escolha aparece na tela do cartão, logo abaixo do dia
  de fechamento, com a dica "Itaú e Mercado Pago: atual · Nubank: próxima. Confira no app do seu banco."
- **Cartão novo** nasce em **"Fatura atual"**. **Cartões que já existiam** ficam em **"Próxima fatura"**,
  exatamente como se comportavam antes: nenhum lançamento mudou de mês na atualização.
- Mudar a escolha (ou o dia de fechamento) **recalcula o mês** das compras daquele cartão, só as que de
  fato mudam (as feitas no dia do fechamento) e só naquele cartão.
- Conta corrente **não muda**: o dia de virada (o do salário) continua abrindo o mês seguinte.
- Banco **v5 → v6**: uma coluna nova, `accounts.closing_day_in_current`, com padrão `false` no banco.

## Por quê

O autor trouxe uma regra pesquisada ("compras no dia do fechamento entram na fatura atual; a partir
do dia seguinte, na do mês seguinte") e pediu para validá-la. **Ela não é universal**:

| Entra na fatura **atual** | Entra na **próxima** |
|---|---|
| Itaú (o fechamento é "o último dia em que as compras entram") | Nubank (blog oficial: "toda compra feita a partir do dia 20 só entra na fatura seguinte") |
| Mercado Pago ("o dia do fechamento é o pior dia; o melhor é o seguinte") | A planilha do próprio autor do app (casos em `competence_test.dart`) |
| A maioria dos guias (Mobills, meutudo, iDinheiro) | |

Como os bancos divergem, **a escolha é do cartão**, e o padrão dos cartões novos segue a leitura da
maioria das fontes ("atual"), decisão do autor.

- **Cartões existentes ficam em "próxima"**: é o que o app sempre fez e o que a planilha do autor usa.
  Mudar de mês compras que ele já conferiu seria surpresa ruim, então o padrão **do banco** é `false` e
  só o cartão criado depois da atualização nasce `true` (`AccountsRepository.create`).
- **Uma única porta para a competência** (`competenceForAccount`): substituiu os pares
  `competenceOf(cutDayFor(...))` espalhados pelo repositório de lançamentos, o formulário e a importação.
  A regra do dia do fechamento só vale para cartão, então ficou junto do dia de corte e não dá para
  esquecer de aplicá-la em algum caminho.
- **Limite conhecido:** o app só guarda a **data**, sem a hora. Os bancos cortam num horário, então uma
  compra feita à noite do dia do fechamento pode cair na fatura oposta à do app. É por isso que a dica
  manda conferir no app do banco.

## Arquivos tocados

- [`competence.dart`](../lib/features/entries/domain/competence.dart) — `competenceOf(..., cutDayStaysInCurrent)` e `competenceForAccount`.
- [`accounts_table.dart`](../lib/features/accounts/data/accounts_table.dart), [`app_database.dart`](../lib/core/database/app_database.dart) — coluna nova e passo `from5To6`; schema em `drift_schemas/`.
- [`accounts_repository.dart`](../lib/features/accounts/data/accounts_repository.dart) — `create`/`update` com a regra; `update` recalcula ao mudar fechamento **ou** regra.
- [`entries_repository.dart`](../lib/features/entries/data/entries_repository.dart) — usa `competenceForAccount` (gravar, ajustar saldo, recalcular).
- [`account_form_screen.dart`](../lib/features/accounts/presentation/account_form_screen.dart) — o seletor.
- Testes: `competence_test`, `repositories_test`, `migration_test` (v5→v6 preserva cartões e meses), `card_closing_rule_test` (tela).

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No aparelho, por cima de um banco v5 com dados: os saldos e os totais do mês ficam **idênticos** e todos
   os cartões abrem em "Próxima fatura". Cartão novo abre em "Fatura atual". Uma compra no dia do
   fechamento cai no mês certo para cada opção; trocar a escolha de um cartão move o mês daquela compra.

## Pendências / próximos passos

- A importação de planilha usa a regra do cartão de destino (o mês é calculado no app), então uma planilha
  de um cartão em "atual" produz meses diferentes da planilha original se ela usava "próxima". Vale
  conferir a escolha do cartão antes de importar.
- Ainda não há aviso ao trocar a escolha de um cartão com muitos lançamentos ("N compras mudam de mês");
  hoje o recálculo é silencioso.
