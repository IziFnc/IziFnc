# Planilhas de exemplo (fictícias)

Planilhas **inventadas** para testar a importação sem usar dados reais. Contas `Azul` e
`Verde`, cartão `Roxo`; nada aqui vem de uma planilha de verdade.

| Arquivo | O que exercita |
|---|---|
| `espelho-do-real` | O esqueleto da planilha real: tabela de Faturas antes de Despesas Gerais (que também começa com "Nome"), Gastos Recorrentes no meio, Entrada de Valor à direita, e pares de transferência (destino em branco e espelho sem data). Duas abas. |
| `deslocado` | Sem Faturas nem Recorrentes; cabeçalho na linha 3. |
| `empilhado` | Entrada de Valor **abaixo** de Despesas Gerais, e não ao lado. |
| `colunas-trocadas` | **Limite conhecido**: colunas em outra ordem. A IA acha a tabela, mas o leitor determinístico assume a ordem `Nome, Valor, Tipo, Banco, Observação, Dia`. |

Cada `.xlsx` tem um `.esperado.json` ao lado: onde ficam as tabelas e o que o leitor deve
extrair (contagens e totais). Esses números são **calculados das próprias linhas gravadas**,
não digitados à mão.

## Regerar

```
dart run tool/gerar_planilhas_exemplo.dart
```

Os bytes são determinísticos: regerar sem mudar os modelos não altera nada no git.

## Acrescentar um modelo

1. Em `tool/planilhas/layouts.dart`, crie uma função que devolve um `GeneratedCase` (use
   `_espelhoDoReal` como exemplo) e inclua-a em `allCases()`.
2. `dart run tool/gerar_planilhas_exemplo.dart`
3. `flutter test test/features/import/corpus_test.dart` — o novo modelo entra sozinho.

## Planilhas reais (privadas)

Para avaliar a IA com planilhas **reais** sem versioná-las, ponha o `.xlsx` e um
`<nome>.esperado.json` (mesmo formato dos daqui) em `_local/planilhas/`. Essa pasta está no
`.gitignore` e é lida por `dart run tool/avaliar_ia.dart`. Nunca commite uma planilha real:
o `tool/validar.dart` reprova qualquer `.xlsx` fora de `docs/exemplo/`.

## Avaliar a IA ao vivo

```
dart run tool/avaliar_ia.dart --providers groq,anthropic --repeat 3
```

Precisa de chave (`GROQ_API_KEY`/`ANTHROPIC_API_KEY` ou `_local/keys/*.txt`) e custa centavos.
Grava um relatório em `_local/eval/`.
