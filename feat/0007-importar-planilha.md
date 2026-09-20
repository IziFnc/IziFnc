# 0007 — Importar planilha `.xlsx`

**Data:** 2026-09-18 · **Status:** ✅ concluído

## O que mudou

O app ganhou um importador (ícone no AppBar da tela do mês, "Importar planilha"): o
autor escolhe o arquivo `.xlsx` da planilha que já usava, escolhe uma aba (um mês do
histórico), mapeia cada par (Banco, Tipo) da aba para a conta/cartão correspondente já
cadastrado no app, revê uma prévia com contagens e confirma. Os lançamentos entram como
`Entry` normais, com a mesma regra de competência de um lançamento manual.

Só as tabelas **Despesas Gerais** e **Entrada de Valor** são lidas — as únicas com data
por linha. **Gastos Recorrentes** fica de fora (a coluna `Dia` lá é 1-31, sem mês).

**Pagamento de fatura e transferência entre contas são importados** (a v1 os pulava —
ver "Decisão revista" abaixo): a fatura vira "Pagar fatura" conta → cartão
(`Banco` = conta, `Observação` = cartão) e a transferência vem do lado Despesas, com o
espelho em Entrada de Valor usado só para completar um destino em branco. O que não dá
para identificar sem chutar vira **erro apontado na prévia**, nunca lançamento adivinhado.

Quem localiza as tabelas na aba é um **LLM** (Groq principal, Anthropic de reserva — ver
abaixo); todo o resto continua em código determinístico.

Reimportar a mesma aba não duplica: cada linha é comparada (conta, tipo, valor,
descrição, data) contra o que já existe, e duplicatas vêm desmarcadas por padrão na
prévia. Datas muito fora do padrão da aba (mais de 40 dias da mediana) também vêm
desmarcadas, com aviso — proteção contra erro de digitação na planilha original.

## Por quê

Este é o diferencial do projeto: o app "engole a planilha do jeito que ela é", em vez de
exigir redigitar o histórico inteiro. A entrega ficou deliberadamente pequena — lição do
primeiro app do autor, que "virou um monstro":

- **Uma aba por vez**, não o arquivo inteiro de uma vez: mantém a prévia pequena e revisável.
- **Transfer/fatura pulados** *(decisão da v1, revista — ver "Decisão revista")*: a análise
  da planilha já tinha marcado grafias inconsistentes de banco ("Bradesco"/"bradesco"/
  "C6"/"c6") como armadilha; parear errado uma transferência é pior do que não importar.
- **Sem pacote pronto para ler `.xlsx`.** A leitura precisa do valor em **cache** da
  célula (nunca reavaliar `<f>`) e precisa olhar o **estilo** da célula (`numFmtId`) para
  saber se é data — comportamento já validado manualmente com um script Python
  (`zipfile`+`xml`) contra a planilha real. Um pacote de terceiros não garante isso.
  Portamos a mesma lógica para Dart com `package:archive` (zip) + `package:xml` (XML),
  ambos puro-Dart.
- **Localizar as tabelas virou trabalho de um LLM, não de heurística.** A primeira
  versão procurava o cabeçalho pela posição (`Nome|Valor|Tipo|Banco|Observação|Dia`).
  No teste manual no emulador com a planilha real isso quebrou: a tabela de **faturas**
  também começa com uma coluna "Nome", e a busca parava nela antes de chegar na linha
  certa (18). Em vez de seguir corrigindo caso a caso, a localização passou a ser feita
  por um LLM, através da interface `LlmTableLocator` — e **só** a localização.
  Valores e datas nunca saem do aparelho: para a API vão apenas os rótulos de texto da
  aba (`describeTextCells`), e a extração continua em código determinístico
  (`readTableRows`), lendo a célula já tipada. É pelo mesmo motivo que o LLM não sugere
  conta nem interpreta valor — quanto menos ele decide sobre dinheiro, melhor.
  Consequência aceita: **a tela de importar passou a exigir internet**; todo o resto do
  app continua offline.

**Descoberta que simplificou o mapeamento:** a coluna `Banco` das tabelas de lançamento
já é o nome específico da conta ou do cartão ("Amazon", "Bradesco", "Caixa", "C6"), não
uma instituição compartilhada entre conta e cartão do mesmo banco. `Banco="Bradesco" +
Tipo="Crédito"` mapeia para **um** cartão específico, sem ambiguidade. O mapeamento virou
uma lista simples de pares distintos (Banco, Tipo) → conta/cartão, sem heurística de
"banco tem dois cartões".

## Arquivos tocados

- [`lib/features/import/data/xlsx_workbook.dart`](../lib/features/import/data/xlsx_workbook.dart) — leitor de `.xlsx` próprio.
- [`lib/features/import/data/spreadsheet_tables.dart`](../lib/features/import/data/spreadsheet_tables.dart) — lê as linhas de uma tabela já localizada (determinístico).
- [`lib/features/import/data/llm_table_locator.dart`](../lib/features/import/data/llm_table_locator.dart) — interface do localizador, prompt compartilhado e `extractTablesWithAi`.
- [`lib/features/import/data/{openai_compatible,groq,anthropic}_table_locator.dart`](../lib/features/import/data/) — o localizador genérico (API da OpenAI), a Groq (caso particular dele) e a Anthropic; [`fallback_table_locator.dart`](../lib/features/import/data/fallback_table_locator.dart) — retry por provedor e reserva; [`configured_table_locator.dart`](../lib/features/import/data/configured_table_locator.dart) — monta a cadeia com as chaves que existem.
- [`lib/features/import/domain/parsed_row.dart`](../lib/features/import/domain/parsed_row.dart) — interpreta as linhas (despesa, entrada, transferência, fatura), casa transferências com o espelho, marca data suspeita.
- [`lib/features/import/domain/build_import_plan.dart`](../lib/features/import/domain/build_import_plan.dart) — monta os lançamentos a partir do mapeamento (função pura); [`import_plan.dart`](../lib/features/import/domain/import_plan.dart) — linha pronta para virar `EntryDraft`.
- [`tool/`](../tool/) — `gerar_planilhas_exemplo.dart`, `avaliar_ia.dart`, `validar.dart`, `corpus.dart`; [`docs/exemplo/`](../docs/exemplo/) — corpus de planilhas fictícias; [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — CI.
- [`lib/features/import/data/import_mapping_repository.dart`](../lib/features/import/data/import_mapping_repository.dart) — sugere e lembra o mapeamento banco/tipo → conta.
- [`lib/features/import/data/import_bank_mappings_table.dart`](../lib/features/import/data/import_bank_mappings_table.dart) — tabela nova (schema v3→v4).
- [`lib/features/import/presentation/import_screen.dart`](../lib/features/import/presentation/import_screen.dart) — a tela, em passos.
- [`lib/features/entries/data/entries_repository.dart`](../lib/features/entries/data/entries_repository.dart) — `saveAll` e `hasDuplicate`.
- [`lib/core/database/app_database.dart`](../lib/core/database/app_database.dart) — migração `from3To4`.
- [`lib/core/router/app_router.dart`](../lib/core/router/app_router.dart), [`lib/features/entries/presentation/month_screen.dart`](../lib/features/entries/presentation/month_screen.dart) — rota e ponto de entrada.

## Como verificar

1. `dart run tool/validar.dart` — analyze, testes (leitor de `.xlsx`, interpretação,
   mapeamento, retry e reserva com `http.Client` falso, corpus de planilhas, migração
   v3→v4), varredura de chaves e verificações de manifesto. É o mesmo que o CI roda.
2. Build com as chaves, sem deixá-las aparecer no histórico do shell — elas moram em
   `_local/keys/` (não versionado):
   `flutter build apk --debug --dart-define=GROQ_API_KEY="$(cat _local/keys/groq.txt)" --dart-define=ANTHROPIC_API_KEY="$(cat _local/keys/anthropic.txt)"`.
3. No app (emulador, nunca no celular do autor com dados de verdade sem antes conferir):
   `adb push planilha.xlsx /sdcard/Download/`, abrir Importar planilha, escolher o arquivo,
   escolher uma aba, mapear os bancos, conferir a prévia (despesas, entradas,
   transferências, faturas, erros) e confirmar. Reimportar a mesma aba deve mostrar tudo
   como duplicata, inclusive transferências e faturas.
   Para conferir sem a planilha real: importe uma das de `docs/exemplo/`.
4. Conferir que o resto do app continua funcionando **sem** internet — só a importação
   deve reclamar de rede.

## Pendências / próximos passos

- Importar Gastos Recorrentes de verdade (com mês, não só dia 1-31) fica para a feature
  0010 (recorrentes).
- Parcelamento (0009) não tem tratamento especial aqui: cada parcela da planilha vira um
  lançamento simples, como já era esperado.
- **Saldos só fecham com o histórico inteiro.** Importar apenas a aba mais antiga deixa
  cartões com "em aberto" **negativo** (as faturas pagam compras do mês anterior, que ainda
  não estão no banco). É o comportamento certo: importe as abas **da mais antiga para a mais
  nova** e ajuste o saldo inicial de cada conta e cartão ("Ajustar saldo") antes da primeira.
- **Decisão revista: fatura e transferência.** A v1 as pulava por cautela, e isso produzia
  os sintomas que o autor reportou: cartões "em aberto" com fatura já paga, C6 negativo
  (−R$ 4.956,45) e Bradesco alto demais — tudo por causa de R$ 4.450,16 em faturas e R$
  6.200 em transferências ignorados. Na planilha real as 3 faturas são inequívocas e as 4
  transferências pareiam por valor com um espelho em Entrada de Valor (que é o lado
  menos confiável: um dos quatro estava sem data), então a fonte é o lado Despesas.
- **Provedor de LLM: decidido.** Três branches foram comparadas na planilha real (aba
  "Dezembro"); ficaram arquivadas como tags `archive/0007-locator-{anthropic,gemini,groq}`.
  **Groq é a principal e a Anthropic é a reserva**; o Gemini ficou fora do produto.

  | Provedor | Resultado no aparelho |
  |---|---|
  | **Anthropic** (`claude-sonnet-5`, tool use forçado) | Funcionou de primeira. 65 lançamentos (na v1, com 8 transferências e 3 faturas puladas e 2 linhas com erro). Pago (US$ 5 de crédito). |
  | **Groq** (`openai/gpt-oss-120b`, `response_format` json_schema) | Funcionou, com **resultado idêntico** ao da Anthropic (mesmos números, mesmas linhas). Grátis. Levou três tentativas de mecanismo — ver abaixo. |
  | **Gemini** (`gemini-3.6-flash`, `responseSchema`) | **Não confiável no tier grátis**: 503 "high demand" em 4 de 4 no app e em 3 de 4 por curl com o schema real; teto de **5 req/min** (429). Sem retry ou com, não fechou o fluxo. |

  **Groq — o que não funcionou antes de funcionar:** (1) `llama-3.3-70b-versatile` saiu
  do catálogo (404); (2) com `tool_choice` forçado, o `gpt-oss-120b` localizou a tabela
  certa mas nomeou os campos `row`/`col` em vez de `headerRow`/`startCol` e a Groq
  recusou a validação; (3) com schema plano, escreveu os quatro valores certos como
  *texto* em vez de chamar a ferramenta ("Tool choice is required, but model did not
  call a tool"). `response_format` estrito resolveu — verificado por curl antes de mexer
  no código. Lição: com modelo aberto, tool calling forçado é menos previsível que saída
  estruturada por schema.

  **Como ficou:** Groq primeiro; se falhar, a Anthropic responde e a tela **avisa** que a
  reserva (paga) foi usada. Provedor sem chave é pulado. O **retry é por provedor**, antes da
  reserva: erro passageiro (429/503/529) é repetido até 3 vezes (2s e 4s); erro permanente
  (chave errada, modelo inexistente, resposta malformada) falha de primeira. Durante a espera
  a tela mostra uma barra de progresso. Modelos aceitam override por
  `--dart-define=GROQ_MODEL=` / `ANTHROPIC_MODEL=` (três provedores tiveram modelo
  aposentado no mesmo dia).

  **Modelo próprio (qualquer serviço compatível com a API da OpenAI).** A Groq é só um caso
  particular de `OpenAiCompatibleTableLocator` (endereço base + modelo + chave opcional).
  `ConfiguredTableLocator` aceita um `resolveCustom`: se houver modelo próprio, ele é tentado
  **antes** de Groq/Anthropic, que ficam de reserva (com o aviso na tela). Serviços de
  terceiros nem sempre aceitam `json_schema`: num `400`, tenta de novo em `json_object` com o
  formato escrito no prompt, e o parser tolera cerca ```json. A tela para configurar isso só
  existe na versão dos testadores.
- **Pipeline de análise e validação.** `tool/gerar_planilhas_exemplo.dart` gera um corpus de
  planilhas **fictícias** em `docs/exemplo/` (`.xlsx` + `.esperado.json`): espelho do layout
  real, deslocado, empilhado e um caso de **limite conhecido** (colunas em outra ordem).
  `corpus_test.dart` exercita o leitor e a interpretação em cada uma (sem rede, roda no CI);
  `tool/avaliar_ia.dart` mede os provedores ao vivo (acerto, tentativas, latência — separando
  "a IA errou" de "provedor indisponível") e aceita planilhas reais privadas em
  `_local/planilhas/`; `tool/validar.dart` é o portão antes de publicar (analyze, testes,
  varredura de chaves nos arquivos e em todo o histórico, `_local/` fora do git, `INTERNET`
  no manifesto) e roda no CI. Primeira rodada ao vivo: Anthropic 10/10; Groq acertou tudo o
  que respondeu, com um 429 do tier grátis.
- **Manifesto:** só os manifestos de debug/profile declaravam `INTERNET`; o principal não.
  Os testes no emulador eram todos em build debug — um APK release falharia em toda
  importação. Corrigido.
- **Se um dia isso for para outras pessoas**, a ideia registrada é limitar: um import de
  planilha grátis no primeiro uso e 5 imports de extrato bancário por mês (com limite de
  páginas). Nada disso está implementado — hoje o uso é aberto, porque é só o autor.
- **Chave de API:** na versão padrão entra só por `--dart-define` no build. A versão de
  testadores (`release/teste-usuarios`) terá uma tela de Configurações para o usuário colocar
  a própria chave; ela **não** entra na `main`.
- **O prompt é específico deste layout** (Despesas Gerais / Entrada de Valor): a planilha de
  outra pessoa provavelmente não será localizada. A avaliação ao vivo mede o quanto a IA
  generaliza, mas generalizar de verdade é outra feature.
