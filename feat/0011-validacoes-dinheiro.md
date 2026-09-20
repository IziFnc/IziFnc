# 0011 — Validações de dinheiro no formulário

**Data:** 2026-09-20 · **Status:** ✅ concluído

## O que mudou

No formulário de lançamento (manual), duas regras de negócio passaram a valer:

- **Transferência:** uma conta não transfere o que não tem. Valor acima do saldo da conta de
  origem é **bloqueado**, com o motivo no campo do valor ("Saldo insuficiente: Bradesco tem
  R$ 100,00."). Transferir exatamente o saldo é permitido. Conta zerada ou no negativo não
  transfere nada.
- **Pagar fatura:** valor acima do que está em aberto no cartão é **bloqueado** ("Acima do que
  está em aberto: Amazon tem R$ 50,00 em aberto."). Pagar **menos** é permitido (pagamento
  parcial; o resto continua no cartão). Cartão sem nada em aberto não recebe pagamento ("Não há
  fatura em aberto em Amazon.").

O aviso aparece no próprio campo do valor ao tocar em Salvar e some sozinho assim que o valor,
a conta, o tipo ou a data mudam.

## Por quê

Dois pontos que o autor achou usando o app: pagar mais do que a fatura deixava o cartão
negativo, e dava para transferir dinheiro que a conta não tinha. A regra que ele fixou: *"uma conta
não pode transferir o que não tem"* — por isso **bloqueia** (a ideia inicial de só avisar e
deixar confirmar caiu).

- **Só no formulário, nunca no repositório.** `EntriesRepository.save` continua sem validar
  saldo, de propósito: a importação de planilha grava o histórico **sem os saldos iniciais** (as
  faturas da aba mais antiga pagam compras de meses que ainda não estão no banco). Uma checagem
  no repositório rejeitaria linhas legítimas. Há um teste que garante isso.
- **Saldo na data do lançamento**, não o de hoje (`balanceOf(conta, today: data)`): lançar uma
  transferência de uma data passada ou futura compara com o que a conta tinha *naquele dia*.
- **Ao editar, o efeito do próprio lançamento é desfeito antes de conferir** (`balanceEffect`).
  Sem isso, editar uma transferência de R$ 50 numa conta que ficou com R$ 50 seria bloqueada por
  uma falta de saldo que a própria transferência criou.
- **Regras puras em `payment_rules.dart`** (sem Flutter), testadas à parte; o formulário só as
  chama.
- **Pagamento parcial e parcelamento** (juros) são a 0012: o bloqueio de "acima do em aberto"
  já convive com o parcial e não atrapalha o que vem depois.

## Arquivos tocados

- [`lib/features/entries/domain/payment_rules.dart`](../lib/features/entries/domain/payment_rules.dart) — `transferBlockedReason`, `billPaymentBlockedReason`, `balanceEffect`.
- [`lib/features/entries/presentation/entry_form_screen.dart`](../lib/features/entries/presentation/entry_form_screen.dart) — chama as regras em `_save` e mostra o motivo no campo do valor.
- Testes: [`payment_rules_test.dart`](../test/features/entries/payment_rules_test.dart) (regras puras) e [`payment_validation_test.dart`](../test/features/entries/payment_validation_test.dart) (formulário: bloqueio, limite exato, parcial, edição, e o repositório sem validar).

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No app: conta com R$ 100 → nova transferência de R$ 150 para outra conta → bloqueia com o motivo;
   R$ 100 passa. Cartão com R$ 50 em aberto → pagar R$ 60 bloqueia; R$ 20 passa e restam R$ 30.
   Editar uma transferência para um valor até (saldo + valor original) passa; um centavo além bloqueia.

## Pendências / próximos passos

- **Pagar fatura não confere o saldo da conta de origem** (só o valor da fatura). Não foi pedido;
  se quiser, é a mesma regra da transferência aplicada ao pagamento.
- **Cheque especial não é tratado:** conta no negativo não transfere. Se fizer falta, o caminho é
  um campo opcional "limite" na conta.
- Nenhuma checagem no **importador**, por decisão (ver acima).
- Não conferi no emulador desta vez: o comportamento está coberto por testes de widget do
  formulário, mas a mensagem em tela real (quebra de linha em texto grande) fica para a 0014.
