# 0003 — Contas, cartões e lançamentos

**Data:** 2026-09-13 · **Status:** ✅ concluído

## O que mudou

Primeira funcionalidade de verdade. O app deixa de ser esqueleto e fica usável à mão:

- **Contas e cartões.** Cadastrar, editar e excluir. Cartão tem dia de fechamento (o
  "Até" da planilha) e de vencimento. Conta e cartão da mesma instituição são dois
  cadastros (Bradesco conta, Bradesco cartão), e há instituição com só cartão (Amazon).
- **Dia de virada do mês.** Configurável, padrão 1. Vale para débito e entradas.
- **Lançamentos.** Despesa ou entrada, com valor, descrição, conta, data e observação.
  Editar e excluir. Cartão só aceita despesa.
- **Tela do mês** (a nova home). Navega entre meses e mostra os totais (entradas, saídas
  no débito, total de cada cartão) e a lista de lançamentos.

O placeholder "Estrutura no ar" da 0001 saiu.

## A regra de mês (o coração desta entrega)

Todo lançamento pertence a um **mês de competência**, que nem sempre é o mês da data dele.
A regra foi definida pelo autor e confirmada na planilha:

> Lançamento **no dia de corte ou depois** já conta para o mês seguinte.

- **Cartão:** o corte é o dia de fechamento. Caixa fecha dia 26: compra em 25/11 fica em
  novembro, compra em 26/11 vai para dezembro.
- **Débito e entradas:** o corte é o dia de virada (o dia do salário). Virada 27: débito
  em 27/11 vai para dezembro.
- Corte maior que o último dia do mês (fechamento dia 30 em fevereiro) cai no último dia.

A regra mora em uma função pura, [`competenceOf`](../lib/features/entries/domain/competence.dart),
coberta com os casos tirados da planilha real.

O formulário mostra **"Vai para: dezembro de 2025"** ao vivo, colado no botão Salvar.
Depois de salvar, a tela do mês pula para o mês em que o lançamento caiu, e não para o
mês que estava aberto. Assim a regra fica visível, e o lançamento nunca parece ter sumido.

## Por quê

**Por que esta feature primeiro, e não a importação da planilha.** A importação precisa
de um destino: um modelo de dados com a regra de mês certa. Construir o destino primeiro,
pequeno e testado, deixa a importação (backlog) só com o trabalho de ler a planilha.
Também é a lição do primeiro app, que cresceu demais: esta entrega tem uma lista
explícita do que ficou de fora.

**Competência gravada, mas derivada.** O mês de cada lançamento é calculado e guardado
na coluna `competence` (`yyyymm`, indexada). Calcular na hora exigiria uma faixa de datas
diferente por conta dentro do SQL. O custo: quando muda o fechamento de um cartão ou o
dia de virada, os lançamentos afetados são **recalculados** na mesma transação. Isso
está testado: mudar o fechamento de um cartão não mexe nos outros, e mudar a virada não
mexe nos cartões.

**Dinheiro em centavos.** O valor é `int` e sempre positivo; o tipo (despesa/entrada)
dá o sinal. O campo de valor é digitado como em app de banco (`1234` vira R$ 12,34),
sem vírgula e sem `double`.

**Conta com lançamento não pode ser excluída.** O banco recusa (`ON DELETE RESTRICT`) e
a tela explica o motivo. O SQLite ignora chave estrangeira por padrão; ela é ligada com
`PRAGMA foreign_keys = ON` ao abrir o banco, e um teste prova que está ativa.

**O tipo da conta não muda depois de criado.** Trocar cartão por conta com lançamentos
existentes deixaria o mês deles sem sentido.

### Desvios do plano, e por quê

- **`Entries`/`Entry` em vez de `Transactions`/`Transaction`.** O drift já tem uma classe
  interna `Transaction`, e o nome gerado colidiria.
- **O drift gera num alvo próprio** ([`build.yaml`](../build.yaml)), num arquivo
  `app_database.drift.dart`. No modo padrão, o `riverpod_generator` não enxerga as classes
  do banco (`Account`, `Entry`) e falha com `InvalidTypeException`. É a receita da
  documentação do drift para usar as classes dele em outros geradores.
- **Web: o banco passou a abrir no navegador.** O `AppDatabase.defaults()` não configurava
  o `DriftWebOptions`, e quebraria na primeira leitura do banco em Chrome.
- **"Salvar" e "Vai para" fixos no rodapé**, dentro do `body`. A primeira versão ficava no
  fim do formulário, que é mais alto que a tela. A segunda usava `bottomNavigationBar`,
  que fica escondido atrás do teclado, como a foto no emulador mostrou. No `body` o
  rodapé sobe junto com o teclado, e há um teste simulando o teclado aberto.

## Fora de escopo (de propósito)

Transferências, pagamento de fatura, saldo das contas, parcelamento, recorrentes,
importação, relatório, categorias, fatura parcial, estorno em cartão, busca, gráficos.
Sem transferências, qualquer saldo de conta sairia errado, por isso a tela mostra só os
**totais do mês**. A ordem das próximas está no [backlog](README.md#backlog).

## Arquivos tocados

- Domínio: [`competence.dart`](../lib/features/entries/domain/competence.dart),
  [`month_summary.dart`](../lib/features/entries/domain/month_summary.dart),
  [`year_month.dart`](../lib/core/utils/year_month.dart),
  [`cents_input_formatter.dart`](../lib/core/utils/cents_input_formatter.dart)
- Banco: tabelas em `lib/features/*/data/*_table.dart`,
  [`app_database.dart`](../lib/core/database/app_database.dart),
  [`build.yaml`](../build.yaml)
- Repositórios: `lib/features/*/data/*_repository.dart`,
  [`repositories.dart`](../lib/core/database/repositories.dart) (providers)
- Telas: [`month_screen.dart`](../lib/features/entries/presentation/month_screen.dart),
  [`entry_form_screen.dart`](../lib/features/entries/presentation/entry_form_screen.dart),
  [`accounts_screen.dart`](../lib/features/accounts/presentation/accounts_screen.dart),
  [`account_form_screen.dart`](../lib/features/accounts/presentation/account_form_screen.dart)
- Removido: `lib/features/dashboard/`

## Como verificar

```bash
dart run build_runner build
flutter analyze        # No issues found!
flutter test           # 46 testes
```

Os testes cobrem: a regra de mês (12 casos), `YearMonth`, o campo de valor, os totais do
mês, os repositórios com banco em memória (competência, recálculo, bloqueio de exclusão,
chave estrangeira) e os fluxos de tela (home vazia, cadastrar conta, lançar, teclado
aberto).

**Cenário manual, feito no Chrome (MCP) e no Pixel 9:**
1. Virada = 27. Cartão Caixa com fechamento 26.
2. Compra em 25/11/2025 → **novembro**. Compra em 26/11/2025 → **dezembro**. O aviso
   "Vai para" mostra isso antes de salvar.
3. Mudar o fechamento para 27 → a compra de 26/11 **volta para novembro**.
4. Android: matar o app (`am force-stop`) logo depois do passo 3 e abrir de novo. O
   fechamento 27 e o recálculo persistem.

## Problemas conhecidos

- **Na web, a última escrita em transação pode se perder ao recarregar a página.** Sem
  isolamento de origem, o Chrome não tem OPFS e o drift grava via IndexedDB. Nesse modo,
  uma edição feita em transação (editar conta, mudar a virada) que seja a **última**
  escrita antes de recarregar não chega ao disco, mesmo esperando 10s. Se qualquer outra
  escrita vier depois, as duas persistem. **O Android não tem o problema**: foi testado
  com `force-stop`. Como a web aqui é só para conferir layout, isso ficou registrado e
  não corrigido.
- **Na web em modo `web-server`, `reload` deixa a página em branco.** Abrir de novo pela
  URL funciona.
- **Asserção do motor web no console** (`window.dart`, redimensionamento na
  inicialização) quando a emulação de celular do MCP já está ativa ao carregar. A pilha
  é toda do Flutter, sem código do app.

## Pendências / próximos passos

- **Próxima entrega: 0004, transferências e pagamento de fatura**, e com elas o saldo
  das contas. Isso vem antes da importação porque, na planilha, "transfer" e "fatura" são
  linhas de débito; importadas como despesa, inflariam os gastos.
- Investigar a perda da última transação na web (drift + IndexedDB), ou ativar OPFS
  servindo a web com os cabeçalhos COOP/COEP. Esta versão do `flutter run` não aceita
  cabeçalhos, então ficaria para um servidor próprio.
