# 0013 — Importar só uma parte da planilha

**Data:** 2026-09-20 · **Status:** ✅ concluído

## O que mudou

- No passo **"Para qual conta ou cartão vai cada um?"**, cada banco da aba ganhou a opção
  **"Não importar"**. O botão **Continuar** deixa de exigir que *todos* os bancos estejam ligados a
  uma conta: basta que cada um tenha uma decisão (uma conta **ou** "Não importar") e que pelo menos um
  entre. Pular tudo não deixa continuar (não importaria nada).
- As linhas dos bancos pulados **ficam de fora sem virar erro**; a prévia diz quantas ("N linha(s)
  ficaram de fora nos bancos que você marcou Não importar").
- Transferência e pagamento de fatura dependem dos **dois lados**: se a origem **ou** o destino foi
  pulado, a linha inteira sai (importar só a metade deixaria o saldo errado).
- Na **prévia**, cada seção (Despesas, Entradas, Transferências, Pagamentos de fatura) ganhou
  **"Desmarcar todas / Marcar todas"**. Marcar/desmarcar linha por linha já existia. O resumo passou a
  dizer "X de Y lançamentos serão importados".
- O "Não importar" vale **só para a aba em que foi escolhido** e **não é lembrado**: as escolhas de
  conta continuam sendo lembradas entre abas, mas pular um banco numa aba não o pula na seguinte.

## Por quê

O autor pediu para poder importar só uma parte, "e não só passar quando importar tudo". A prévia já
deixava desmarcar linhas; o que **travava** era o mapeamento, que só liberava o Continuar com todos os
bancos da aba mapeados. Quem ainda não cadastrou o cartão de um banco, ou não quer aquele banco, ficava
sem saída.

- **Escolha explícita, não "erro silencioso":** já existia, no plano, o caminho "sem mapeamento →
  linha ignorada com erro", mas ele era inalcançável pela tela. Um banco com 40 linhas viraria 40 erros
  vermelhos. "Não importar" é uma decisão do usuário, então entra como número, não como erro.
- **Regra no domínio, não na tela:** `canContinueMapping` e o parâmetro `skipped` de `buildImportPlan`
  são funções puras e testadas; a tela só liga os botões a elas.
- **Não lembrar o "não importar":** lembrá-lo poderia esconder dados numa importação futura sem o
  usuário perceber. A conta escolhida continua sendo lembrada (é só conveniência).

## Arquivos tocados

- [`build_import_plan.dart`](../lib/features/import/domain/build_import_plan.dart) — `skipped`, `ImportPlan.leftOutByChoice` e `canContinueMapping`.
- [`import_screen.dart`](../lib/features/import/presentation/import_screen.dart) — chip "Não importar", nova condição do Continuar, resumo e "marcar todas" por seção.
- Testes: `test/features/import/build_import_plan_test.dart` (bancos pulados, transferência/fatura com lado pulado, `canContinueMapping`).

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No app: importar uma aba com mais de um banco, marcar um como "Não importar", ligar os outros a
   contas, continuar: a prévia mostra só os bancos escolhidos e diz quantas linhas ficaram de fora. Em
   qualquer seção, "Desmarcar todas" zera a seção e o botão final mostra o novo total.

## Pendências / próximos passos

- Não há teste de widget do fluxo (o seletor de arquivo é um canal de plataforma); a conferência da tela
  foi feita no emulador.
- Ainda não dá para importar só um intervalo de **datas** ou só uma **conta** direto na prévia; hoje é por
  banco (no mapeamento) e por linha/seção (na prévia).
