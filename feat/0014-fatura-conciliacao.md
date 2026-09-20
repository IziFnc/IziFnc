# 0014 — Pagar fatura com conciliação e juros opcionais

**Data:** 2026-09-20 · **Status:** ✅ concluído

## O que mudou

No formulário de **Pagar fatura** (pagamento novo):

- Campo opcional **"Juros e encargos desta fatura"**. Serve para quando a fatura do banco veio **maior**
  que o "em aberto" do app (juros, multa, IOF, anuidade). Vazio significa nenhum juros.
- Com juros informados, o app grava **na mesma transação** (ou entram os dois, ou nenhum):
  1. um **gasto** no cartão, "Juros e encargos da fatura" (entra nos totais do mês, porque é gasto novo), e
  2. o **pagamento** da fatura.
- A regra de bloqueio da 0011 passa a ser: o valor pago pode ir até o **em aberto mais o juros**. Sem
  juros, continua bloqueando acima do em aberto.
- **Linha ao vivo** abaixo do campo: "R$ X continuam em aberto e entram na próxima fatura" (quando se paga
  menos que a fatura) ou "Fatura quitada".
- Ao **editar** um pagamento existente o campo de juros não aparece: o juros já é um gasto à parte,
  editável na lista.

## Por quê

O autor sugeriu deixar escrever (ou não) os juros e ajustar quando a fatura vem maior ou menor, com a
diferença indo para a fatura seguinte, e pediu um parecer sobre valer ou não para a experiência.

**Parecer:** vale, e cabe **sem mudar o banco**, porque o app não modela faturas como objetos: o saldo do
cartão é um total corrido (em aberto = −saldo) e o mês agrupa por competência.

- **Fatura MENOR que o em aberto** (compra que o banco ainda não lançou, estorno…): não precisa de mecanismo
  novo. Paga-se o valor real, e a diferença **continua em aberto no cartão** e entra na próxima fatura, que
  é o pagamento parcial já permitido desde a 0011. Faltava só **dizer isso na tela**, e agora diz.
- **Fatura MAIOR**: era o caso que exigia "Ajustar saldo" numa tela e depois pagar em outra, e o ajuste
  **não entra nos totais** (escondia o juros). Agora é uma tela só e o juros aparece como gasto.
- **O que não fazemos:** mover a diferença automaticamente para outro mês, ou aceitar pagar acima sem
  explicar — os dois esconderiam um erro de lançamento. Tudo é confirmado pelo usuário, nunca automático.
- **Sem taxa embutida** (decisão dele, com base na pesquisa: as taxas de parcelamento variam de 1% a 19% ao
  mês entre bancos). O usuário digita o valor que o banco cobrou.
- A data do gasto de juros é a do pagamento; a competência segue a regra do cartão. Isso pode deslocar o
  juros um mês em relação à fatura a que ele pertence, e está anotado como pendência.

## Arquivos tocados

- [`payment_rules.dart`](../lib/features/entries/domain/payment_rules.dart) — `billPaymentBlockedReason(interestCents)` e `billPaymentOutcome`.
- [`entry_form_screen.dart`](../lib/features/entries/presentation/entry_form_screen.dart) — campo, resumo ao vivo e gravação atômica com `saveAll`.
- Testes: `payment_rules_test`, `payment_validation_test` (juros libera, continua bloqueando além dele, resumo ao vivo, edição sem o campo); um teste antigo do `widget_test` ganhou janela alta porque o formulário ficou mais comprido.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No app: cartão com R$ 50,00 em aberto → Pagar fatura de R$ 58,00 com juros de R$ 8,00 passa, deixa o
   cartão zerado e cria o gasto "Juros e encargos da fatura". Sem juros, R$ 58,00 bloqueia. Pagar R$ 20,00
   mostra "R$ 30,00 continuam em aberto e entram na próxima fatura".

## Pendências / próximos passos

- **Parcelar a fatura** fica junto do parcelamento de compras (parcelas futuras; parcela = principal + juros,
  e só o juros é gasto novo, senão o total do mês duplica).
- Calculadora de taxa/parcela e tabela de referência do Banco Central: adiadas (decisão: juros aberto).
- O juros é lançado na data do pagamento; se a fatura fechou antes, ele pode cair um mês depois da fatura
  a que pertence.
