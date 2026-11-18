# 0044 — Revisão de textos e teste do importador com planilhas diferentes (1.0.4)

**Data:** 2026-11-16 · **Status:** ✅ concluído (textos, planilhas diferentes, avaliação da IA e teste no emulador)

## O que mudou

- **Textos que presumiam a planilha de uma pessoa.** O cadastro de cartão dizia `(o "Até" da planilha)` e citava bancos como regra
  ("Itaú e Mercado Pago: atual · Nubank: próxima"); a escolha do arquivo e os erros falavam em "Despesas Gerais" e "Entrada de Valor"
  como se fossem o padrão do mundo. Agora o app fala em "tabela de gastos" e "tabela de entradas", pede que se confira no app do banco e
  avisa que outros formatos podem falhar. Também saiu a "conta dona" da validação do cartão ("conta que paga a fatura deste cartão") e as
  mensagens de excluir conta com lançamentos ou cartões ficaram diretas.
- **Revisão por agentes** (um Sonnet leu todos os textos, um Haiku leu como pessoa nova). A lista completa de achados está no cofre; o que
  não entrou (vocabulário "lançamento" em todo lugar, "Principal/Reserva" da IA, jargão de privacidade) vira decisão de vocabulário.
- **Trava** `test/core/texts_test.dart`: falha se o texto "da planilha" com aspas de coluna, banco citado como regra, nome de aba do autor ou o
  nome antigo do app voltarem para `lib/`.

- **Nove planilhas fictícias de forma diferente** (`tool/planilhas/layouts_extra.dart`, em `docs/exemplo/`): rótulos em inglês e sinônimos
  (suportados), coluna extra e data em texto (limites), e cinco formas sem as duas tabelas do app (valor com sinal, extrato, mês em colunas, abas por
  banco, só gastos). O `corpus_test` cobre todas; onde não há tabelas, afirma que o app diz "não achei".
- **Mensagem de "tabela não achada"** reescrita: explica o formato que o app lê antes de sugerir tentar de novo.
- **Medição** (cofre, `entregas/import-planilhas-diferentes.md`): a IA acha o layout mesmo com rótulos diferentes e **não inventa tabela** onde não há;
  no emulador, 12 de 13 casos passam. Falha real: `data-em-texto` leva a um passo de bancos vazio sem explicação (próxima versão).

## Por quê

O autor viu o texto no cadastro de cartão ao testar o Ambrio e lembrou que nem todo mundo usa a planilha dele. O app agora é portfólio e
será visto por quem não conhece o layout original.

## Como verificar

`flutter test test/core/texts_test.dart` e `dart run tool/validar.dart`.
