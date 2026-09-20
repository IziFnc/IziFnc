# 0006 — Cartão vinculado à conta e "Pagar fatura"

**Data:** 2026-09-14 · **Status:** ✅ concluído

## O que mudou

- **Todo cartão pertence a uma conta.** No cadastro do cartão entra "Conta vinculada"
  (obrigatória): o Amazon é do Bradesco, o "Cartão Bradesco" também.
- **A tela de contas agrupa**: cada conta aparece com os seus cartões recuados logo
  abaixo. Cartão sem conta dona (os que vieram de antes desta entrega) aparece no fim,
  em vermelho: "sem conta vinculada — toque para vincular".
- **"Pagar fatura" é um tipo próprio de lançamento.** O formulário tem Despesa ·
  Entrada · Transferência · Pagar fatura (chips que quebram de linha). No pagamento,
  você escolhe o cartão, que mostra o valor em aberto, e o "Sai de" já vem com a conta
  dona dele.
- **Transferência é só entre contas.** Cartão não aparece em "De" nem em "Para"; com
  uma conta só, a opção fica desabilitada.
- **Rótulos:** no "Onde", o cartão aparece como "Amazon · cartão do Bradesco". Na lista
  do mês, o pagamento aparece como "Bradesco → fatura Amazon". Nos totais, "Cartão
  Bradesco" não vira "Cartão Cartão Bradesco".

## Por quê

Achado do autor testando no celular: transferência só faz sentido entre contas que
guardam dinheiro, e um cartão pertence a uma conta.

**A decisão de modelo foi do autor, e simplificou o plano.** O plano inicial dava ao
cartão funções "débito" e "crédito", com uma escolha "Débito | Crédito" na compra. Ele
apontou que **débito é da conta**: compra no cartão de débito, pix ou débito automático
é dinheiro saindo da conta, e o app já lança assim. Então o cartão é **sempre de
crédito**, e só ganha a conta a que pertence. A mudança no banco caiu para uma coluna.

*Custo aceito:* o app não distingue débito com cartão de pix. A planilha também não (a
coluna `Tipo` é só Débito/Crédito), e isso não afeta saldo, mês ou totais.

**Mapeamento direto da planilha** (preparação da importação, 0007):
- `Banco = Bradesco` + `Tipo = Débito` → a conta Bradesco
- `Banco = Bradesco` + `Tipo = Crédito` → o cartão de crédito vinculado ao Bradesco
- linha "fatura" com a Observação apontando o cartão → `billPayment`
- linha "transfer" entre bancos → `transfer`

**`billPayment` separado de `transfer`**: a intenção fica explícita no dado, para o
relatório (0008) e a importação. No saldo e nos totais ele se comporta como a
transferência para cartão de antes: sai da conta, abate a dívida do cartão e não conta
como gasto.

## Migração v2 → v3

Mesmo fluxo da 0004 (`make-migrations`). O passo `from2To3`:

```sql
-- adiciona accounts.linked_account_id (nulo para os cartões existentes)
UPDATE entries SET type = 'billPayment'
WHERE type = 'transfer'
  AND to_account_id IN (SELECT id FROM accounts WHERE kind = 'creditCard');
```

O teste de preservação v2 → v3 cobre os casos que importam: o pagamento para cartão
vira `billPayment`, a transferência entre contas continua `transfer`, o ajuste continua
igual e o cartão sai sem conta dona.

**Testada no emulador** instalando por cima da 0005: o "Pagamento fatura Caixa" antigo
passou a aparecer como "Bradesco → fatura Caixa", com os saldos iguais.

## Regras (todas com teste)

| Operação | Regra |
|---|---|
| Criar cartão | exige conta vinculada (uma conta, não outro cartão) e fechamento |
| Editar cartão | exige vínculo (é assim que os cartões migrados ganham o seu) |
| Transferência | conta → conta, diferentes; cartão como destino é recusado |
| Pagar fatura | sai de uma conta; destino tem que ser cartão |
| Excluir conta | bloqueado se for dona de algum cartão |

## Arquivos tocados

- Modelo: [`accounts_table.dart`](../lib/features/accounts/data/accounts_table.dart)
  (`linkedAccountId`), [`entry_type.dart`](../lib/features/entries/domain/entry_type.dart)
  (`billPayment`, `hasDestination`), [`app_database.dart`](../lib/core/database/app_database.dart)
  (v3 + `from2To3`), `drift_schemas/`, `test/drift/`
- Regras: [`accounts_repository.dart`](../lib/features/accounts/data/accounts_repository.dart)
  (dona obrigatória, `countCardsOf`, `AccountHasCardsException`),
  [`entries_repository.dart`](../lib/features/entries/data/entries_repository.dart)
  (`_checkDestination`, `billPayment` no SQL de saldo)
- Telas: [`account_form_screen.dart`](../lib/features/accounts/presentation/account_form_screen.dart)
  (`_OwnerPicker`), [`accounts_screen.dart`](../lib/features/accounts/presentation/accounts_screen.dart)
  (agrupado), [`entry_form_screen.dart`](../lib/features/entries/presentation/entry_form_screen.dart)
  (chips de tipo, fluxo de pagamento), [`month_screen.dart`](../lib/features/entries/presentation/month_screen.dart),
  [`account_label.dart`](../lib/features/accounts/presentation/account_label.dart)
  (`cardTitle`, dona no rótulo)

## Como verificar

```bash
dart run build_runner build && flutter analyze && flutter test   # 90 testes
```

**Emulador (feito):**
1. Depois da atualização: "Bradesco → fatura Caixa", e o Caixa com o aviso de vínculo.
2. Vincular o Caixa ao Bradesco (sai o aviso); criar o "Cartão Bradesco" (aparece
   recuado abaixo do Bradesco).
3. R$ 20 na conta Bradesco e R$ 30 no cartão: Saídas no débito R$ 20, cartão R$ 30.
4. Pagar fatura: o cartão mostra "R$ 30,00 em aberto", o "Sai de" já vem no Bradesco e
   Transferência fica desabilitada. Depois: Bradesco R$ 550,00, cartão quitado sai do
   bloco, totais iguais.
5. `force-stop` e abrir de novo: tudo igual.

## Pendências / próximos passos

- **Próxima: 0007, importar a planilha.** O modelo agora espelha as colunas dela.
- O seu celular (conectado ao computador) **não foi tocado**: a instalação e a migração
  rodaram só no emulador. Ao instalar no celular, os cartões que você já tem vão
  aparecer com o aviso de vínculo, e basta tocar em cada um e escolher a conta.
