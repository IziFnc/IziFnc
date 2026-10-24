# 0035 — Limite de tamanho de arquivos e refatoração

**Data:** 2026-10-23 · **Status:** ✅ concluído

## O que mudou

- `tool/tamanho_arquivos.dart`, chamado por `tool/validar.dart` (logo, pelo CI): em `lib/`
  avisa acima de 250 linhas e **falha acima de 400**; em `test/` falha acima de 500. Arquivo
  gerado não conta. `tool/tamanho_excecoes.txt` guarda tetos que só encolhem; hoje está vazia.
- Os oito arquivos que passavam do limite foram divididos, sem mudança de comportamento:

| Arquivo | Antes | Depois |
|---|---|---|
| `entry_form_screen.dart` | 866 | 396 |
| `import_screen.dart` | 852 | 322 |
| `account_form_screen.dart` | 644 | 390 |
| `parsed_row.dart` | 576 | 185 |
| `month_screen.dart` | 417 | 297 |
| `ai_settings_screen.dart` | 414 | 40 |
| `repositories_test.dart` | 898 | 4 arquivos de 124 a 301 |
| `migration_test.dart` | 649 | 4 arquivos de 162 a 206 |

## Por quê

Arquivo grande esconde onde mexer e faz cada mudança arriscar o resto. O limite no CI
impede que o problema volte; a lista de exceções que só encolhe permitiu migrar sem travar
o trabalho. Nenhuma tela mudou de aparência ou de fluxo.

O `import_screen` manteve no widget raiz a observação de `accountsProvider` e
`monthStartDayProvider` em todos os passos: sem ela o `autoDispose` derruba a importação no
meio (a regressão do rc.3).

## Arquivos tocados

Muitos; os principais estão na tabela. Widgets novos em `lib/features/*/presentation/`
(`entry_form_fields`, `entry_account_section`, `import_*_step`, `account_card_fields` …) e
`test/support/repo_fixture.dart`.

## Como verificar

- `flutter test` (554 testes, o mesmo número de antes da refatoração).
- `dart run tool/validar.dart; echo "exit=$?"`.

## O que não foi verificado

- **Nenhum roteiro no aparelho** depois da refatoração. A rede de proteção foi a suíte e a
  matriz de telas (texto × tema), que cobrem layout e fluxo, mas não substituem tocar na
  tela, principalmente a importação e o formulário de lançamento.
- Os arquivos novos de `lib/` foram formatados com o `dart format` padrão e os antigos
  seguem com linhas mais largas; o estilo ficou misto.
- `entry_form_screen` ficou em 396, quase no limite; a próxima mudança lá já pede outra
  extração.

## Pendências / próximos passos

- Passar um roteiro rápido no celular real (lançamento novo, editar, pagar fatura, importar).
