# 0004 — Transferências, pagamento de fatura e saldo das contas

**Data:** 2026-09-13 · **Status:** ✅ concluído

## O que mudou

- **Transferência** entre contas: sai de uma conta corrente e entra em outra conta.
- **Pagamento de fatura:** é uma transferência cujo destino é um cartão. A descrição é
  sugerida sozinha ("Pagamento fatura Amazon") e continua editável.
- **"Saldos hoje" no topo da tela inicial**, como o bloco "Bancos" da planilha: saldo de
  cada conta corrente, o total, e quanto está **em aberto** em cada cartão. Cartão
  quitado sai do bloco. Tocar numa linha abre a conta.
- **Ajustar saldo:** na edição da conta, você informa o saldo que o banco mostra (ou o
  valor em aberto, no cartão) e o app registra a diferença como um lançamento "Ajuste
  de saldo". Serve para o saldo inicial e para corrigir depois, e substitui os números
  digitados à mão dentro das fórmulas da planilha (`+975-86.5`).
- **Transferências e ajustes não entram nos totais do mês.** Pagar a fatura não é gastar
  de novo, e ajuste não é renda.
- **A primeira migração de banco do projeto** (schema v1 → v2).

## Por quê

**Por que antes da importação da planilha.** Na planilha, "transfer" e "fatura" são
linhas de débito. Sem transferência no modelo, a importação trataria essas linhas como
despesa e inflaria os gastos. E sem transferência não existe saldo de conta que feche.

**Uma fórmula de saldo para conta e cartão.** Todo saldo é
`+ entradas + ajustes de aumento + transferências que chegam − despesas − ajustes de
redução − transferências que saem`. No cartão isso dá negativo (é dívida), e a tela
mostra o oposto como "em aberto". A soma é feita no SQL (`customSelect` reativo), porque
depois da importação serão milhares de linhas. Lançamento com data futura não entra no
saldo de hoje.

**Dois tipos de ajuste (`adjustmentIncrease`/`adjustmentDecrease`), não um valor com
sinal.** A tabela tem `CHECK (amount_cents > 0)`. Valor com sinal exigiria mudar o CHECK,
e o SQLite só faz isso recriando a tabela na migração. Com dois tipos, a migração **só
adiciona uma coluna**, que é a operação mais segura que existe.

**A transferência segue a regra de mês da conta de origem**, porque o dinheiro sai de lá.
Não muda nada na `competenceOf` nem no recálculo, que já usavam a conta do `account_id`.

**Cartão mostra só o total em aberto.** O status por fatura (pago/restante mês a mês,
como a tabela de faturas da planilha) é a feat "fatura parcial", que o autor pediu para
depois.

**Ajuste não se edita, só se exclui.** Ele é a diferença de um momento; para corrigir,
ajusta-se de novo. Aberto pela lista, mostra os dados e o botão excluir.

## A migração v1 → v2

Feita com o `drift_dev make-migrations`, que o próprio Drift recomenda:

1. Foto do schema v1 **antes** de mexer nas tabelas (`drift_schemas/app_database/drift_schema_v1.json`).
2. Tabelas alteradas, `schemaVersion` → 2, e a ferramenta rodada de novo. Isso gerou o
   schema v2, o [`app_database.steps.dart`](../lib/core/database/app_database.steps.dart)
   e o [teste de migração](../test/drift/app_database/migration_test.dart).
3. `onUpgrade: stepByStep(from1To2: … m.addColumn(schema.entries, schema.entries.toAccountId))`.

O teste gerado confere o schema. O teste de **preservação de dados** foi preenchido com
dados parecidos com os reais (virada 27, cartão fechando 26, compra de 26/11, uma entrada
com observação): tudo sobrevive, e `to_account_id` nasce nulo.

**Testado num aparelho de verdade:** o app da 0003, com dados, foi atualizado por cima
no emulador. O cartão Caixa e a compra de 26/11 continuaram lá, e o bloco novo já
mostrou "Caixa em aberto R$ 10,00" calculado sobre os dados antigos.

O `make-migrations` lê as opções do primeiro builder drift habilitado, que no nosso
[`build.yaml`](../build.yaml) de dois alvos é o `not_shared`. Por isso as opções ficam
na âncora `&drift_options`.

## Arquivos tocados

- Modelo: [`entry_type.dart`](../lib/features/entries/domain/entry_type.dart) (3 tipos,
  `affectsMonthTotals`), [`entries_table.dart`](../lib/features/entries/data/entries_table.dart)
  (`toAccountId`), [`app_database.dart`](../lib/core/database/app_database.dart) (v2 + `stepByStep`)
- Regras: [`entries_repository.dart`](../lib/features/entries/data/entries_repository.dart)
  (validação de transferência, `watchBalances`, `adjustBalance`, `countForAccount` com
  destino, `watchMonth` com a conta de destino)
- Telas: [`month_screen.dart`](../lib/features/entries/presentation/month_screen.dart) (bloco
  de saldos), [`entry_form_screen.dart`](../lib/features/entries/presentation/entry_form_screen.dart)
  (Despesa | Entrada | Transferência, "De"/"Para"),
  [`account_form_screen.dart`](../lib/features/accounts/presentation/account_form_screen.dart)
  (saldo + Ajustar)
- Migração: `build.yaml`, `drift_schemas/`, `app_database.steps.dart`, `test/drift/`
- **Formatação:** o `dart format` foi aplicado em todo o projeto. Vários arquivos da 0003
  aparecem no diff só por quebra de linha, sem mudança de comportamento.

## Como verificar

```bash
dart run build_runner build
flutter analyze        # No issues found!
flutter test           # 67 testes, incluindo 2 de migração
```

**Android (feito no Pixel 9, por cima do app da 0003):**
1. Os dados antigos aparecem depois da atualização.
2. Criar Bradesco e ajustar para R$ 500,00.
3. Pagar R$ 10,00 da fatura do Caixa a partir do Bradesco.
4. A home mostra Bradesco R$ 490,00, o Caixa sai do bloco, e "Saídas no débito" continua
   R$ 0,00.
5. `am force-stop`, abrir de novo: tudo igual, inclusive novembro com a compra antiga.

**Web (MCP):** home com saldos, total e ajuste, em 393×852, conferidos por screenshot.

## Problemas encontrados e resolvidos durante a entrega

- **"Transferência" quebrava em duas linhas** no seletor de tipo, num celular de 393dp.
  O ✓ do item selecionado comia a largura; foi removido, e a cor de fundo marca a seleção.
- **O seletor de tipo ia oferecer "Ajuste de saldo"**, porque percorria o enum inteiro.
  Agora oferece só Despesa, Entrada e Transferência.
- **A porta web 5555 colidia com o emulador Android**: o `emulator-5554` usa a 5555 para
  o `adb`. A convenção passou a ser a **8765**, fora da faixa 5554–5585. As entradas 0001
  e 0002 citam 5555 e ficam como histórico.

## Descoberto sobre o ambiente de teste web (não é bug do app)

**Emular o celular com a página aberta recarrega a página**, porque o Chrome recarrega
ao ligar os modos `mobile` e `touch`. No modo debug `web-server`, esse recarregamento
deixa a conexão com o Drift presa, e o app fica no carregamento infinito. Enquanto houver
uma aba daquela origem aberta, as outras também ficam presas.

Fiz uma bisecção para confirmar que não era o código da 0004: o código da 0003, o da 0003
só com as mudanças de banco da 0004, e o código atual completo abriram normalmente em
origens novas. O travamento aparece quando se emula com a página já aberta.

**Procedimento certo:** emular primeiro, numa aba vazia, e **depois** navegar para o
app. Está no README.

## Pendências / próximos passos

- **Próxima: 0005, importar a planilha `.xlsx`.** Agora o modelo tem tudo o que a
  planilha usa: despesa, entrada, transferência, pagamento de fatura e ajuste de saldo.
- Status por fatura (fatura parcial): segue no backlog.
- A migração **na web** não pôde ser testada com dados antigos, porque a troca de porta
  mudou a origem do IndexedDB e o banco antigo da 5555 ficou inacessível. A migração que
  importa, a do Android, foi testada com dados reais.
