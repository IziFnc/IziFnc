# 0025 — Importação com a planilha real: sem data, parcelas, fatura sem cartão

**Data:** 2026-09-22 · **Status:** ✅ concluído

## O que mudou

O autor importou uma aba da planilha real e o app trouxe **~50** dos **~70** lançamentos que ele contou.
Um diagnóstico novo, aba por aba, mostrou onde as linhas iam parar. Das 10 abas, ~20% das linhas não
viravam lançamento, por quatro motivos. As três primeiras regras foram decididas por ele:

- **Linha sem data** (32 no total, sempre no fim da tabela): entra, com a **última data da aba** (o "fim do
  mês da aba", calculado só com as datas normais, então não pula de mês). A observação diz "sem data na planilha".
- **Parcela com a data da compra original** (6 a 11 por aba; vinham **desmarcadas** como "data suspeita"): entra
  marcada, no **mesmo dia no mês da aba** (dentro das datas da aba), e a observação guarda a data da compra.
  Vale para os dois formatos da planilha: "4/10" (desde maio) e o **antigo**, em que a Observação é a data da
  última parcela guardada como número (só enquanto o parcelamento ainda corre no mês da aba).
- **Fatura sem o cartão** (13; Observação vazia): entra; o cartão é **perguntado no mapeamento**
  ("Fatura sem cartão · paga por Azul"), uma pergunta por conta pagadora, lembrada nas próximas abas.
- **IA que não acha uma tabela:** numa rodada a Entrada de Valor de uma aba não foi encontrada e na seguinte foi.
  Agora o app tenta **uma segunda vez** sozinho; se ainda faltar, a mensagem diz qual tabela e sugere tentar de
  novo (antes dizia, errado, "este arquivo não parece .xlsx válido").
- **Prévia sem sumiço calado:** avisos dizem quantas vieram desmarcadas, quantas parcelas foram trazidas para o
  mês, quantas estavam sem data, quantas faturas usam o cartão escolhido, quantas transferências aparecem duas
  vezes na planilha (e entram uma) e que "Gastos Recorrentes" ainda não é importada.

**Resultado na planilha real** (só contagens): de 3 a 10 erros por aba caiu para **3 no total** (uma linha só
com nome e observação, e duas transferências recebidas sem a saída), e as desmarcadas por data de 6 a 12 por aba
para **0 a 3** (datas de fato fora do mês, para revisar).

## Plano de teste (planilhas diferentes)

- **`tool/diagnosticar_planilha.dart`**: roda o pipeline do app em cada aba de um `.xlsx` e mostra **só números**
  (lidas, sem Nome, erros e o campo que falhou, espelhos, lançamentos, desmarcadas, corte de leitura, outras
  tabelas). O detalhe por linha (sem valores nem descrições) vai para `_local/eval/`.
- **Corpus fictício ampliado:** o modelo `armadilhas-do-real` reproduz os traços com dados inventados; o
  `corpus_test` passou a exigir também **zero desmarcadas por data** nos modelos suportados.
- **Rotina para uma planilha nova:** `dart run tool/diagnosticar_planilha.dart caminho.xlsx` → conferir os números
  com o autor → se aparecer um traço novo, criar um modelo fictício equivalente em `tool/planilhas/layouts.dart` →
  `dart run tool/avaliar_ia.dart` para a localização ao vivo. A planilha real nunca entra no git.

## Por quê

- **Sem data no fim da tabela:** gastos do mês sem dia certo; perder 3 a 7 por aba distorce o total.
- **Parcela no mês da aba, não na data da compra:** com a data original o lançamento cairia num mês antigo e
  somaria errado no mês certo.
- **Fatura sem cartão perguntada, não adivinhada:** a linha só diz a conta que pagou.
- **Critério estreito para o formato antigo de parcela:** só Observação-data depois da compra e parcelamento ainda
  corrente; o resto (possível erro de digitação) segue desmarcado para revisar.

## Arquivos tocados

- [`parsed_row.dart`](../lib/features/import/domain/parsed_row.dart) — `undated`, `originalDate`, `lastInstallment`, `cardUnknown`, `unknownCardName`, resolução das datas.
- [`build_import_plan.dart`](../lib/features/import/domain/build_import_plan.dart) — descrição/observação e `importNotes`.
- [`llm_table_locator.dart`](../lib/features/import/data/llm_table_locator.dart) — segunda tentativa e `TablesNotFoundException`; [`import_error_message.dart`](../lib/features/import/domain/import_error_message.dart).
- [`import_screen.dart`](../lib/features/import/presentation/import_screen.dart) — avisos na prévia.
- [`tool/diagnosticar_planilha.dart`](../tool/diagnosticar_planilha.dart), [`tool/planilhas/layouts.dart`](../tool/planilhas/layouts.dart), `docs/exemplo/armadilhas-do-real.*`.
- Testes: `parsed_row_test`, `build_import_plan_test`, `llm_table_locator_test`, `import_error_message_test`, `corpus_test`.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. `dart run tool/diagnosticar_planilha.dart <sua planilha>` e comparar com a sua contagem.
3. No app: importar a mesma aba de novo; a prévia mostra os avisos e o total bate (menos Recorrentes).

## Pendências / próximos passos

- **Gastos Recorrentes** continua fora (entrega própria, no backlog).
- As 2 transferências recebidas sem saída seguem como erro visível: podem ser dinheiro vindo de fora (seria
  entrada) — decidir quando aparecerem de novo.
- Corpus privado com contagens conferidas (`_local/planilhas/*.esperado.json`) quando o autor validar os números.
