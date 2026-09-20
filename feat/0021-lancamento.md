# 0021 — Lançamento: tipos em grade fixa, "Salvar e novo" e desfazer ao excluir

**Data:** 2026-09-21 · **Status:** ✅ concluído

## O que mudou

- **Tipos em grade 2×2 fixa** (Despesa, Entrada / Transferência, Pagar fatura). Antes eram chips num `Wrap`
  que mudavam de linha conforme o tipo escolhido: a posição de cada um pulava a cada troca.
- **"Salvar e novo"** ao criar (não aparece ao editar): grava, limpa valor, descrição, observação e juros,
  **mantém tipo, contas e data** (o que costuma repetir), devolve o foco ao valor e mostra no rodapé
  "Salvo: Café · R$ 10,00" até a pessoa começar o próximo valor. O "Salvar" de sempre continua fechando a tela.
- **Excluir com Desfazer.** O diálogo "Excluir lançamento? Não dá para desfazer." saiu: exclui na hora e
  mostra "Lançamento excluído. **Desfazer**" por 6 segundos. Vale também para o ajuste de saldo aberto da lista.
  Por trás, `EntriesRepository.restore` devolve a linha **idêntica** (mesmo id, data, competência e criação).

## Por quê

Resultado da auditoria de UX (achados L1, L2 e L3, escolhidos pelo autor).

- **Por que sem "tem certeza?":** a pergunta antes de agir é respondida com "sim" sem ler, e o erro só
  aparece depois; poder desfazer depois protege de verdade e tira um toque do caminho normal.
- **Confirmação no rodapé, não num SnackBar:** o primeiro desenho usava um SnackBar, e o teste mostrou que
  ele **cobre o botão "Salvar e novo"** justamente quando se quer tocar nele de novo (o toque falhava).
  Trocado por uma linha no próprio rodapé, que não tapa nada.
- **O "Desfazer" fica no `ScaffoldMessenger` do app**, não na tela do formulário, para continuar visível na
  lista para onde se volta depois de excluir.

## Arquivos tocados

- [`entry_form_screen.dart`](../lib/features/entries/presentation/entry_form_screen.dart) — grade, rodapé, `_save(andNew)`, `_resetForNext`, `_deleteWithUndo`.
- [`entries_repository.dart`](../lib/features/entries/data/entries_repository.dart) — `restore`.
- Testes: `entry_form_ux_test` (grade, salvar e novo, desfazer) e `repositories_test` (restore de lançamento e de transferência).

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No app: + → troque de tipo (nada muda de lugar); lance com "Salvar e novo" três vezes seguidas; abra um
   lançamento, exclua e toque em Desfazer.

## Pendências / próximos passos

- **0022** home e **0023** importação (ver `feat/README.md`).
- "Salvar e novo" não copia a descrição; se o uso mostrar que se repete muito (ex.: "Uber"), dá para manter.
