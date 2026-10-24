# 0033 — Relógio injetável

**Data:** 2026-10-23 · **Status:** ✅ concluído

## O que mudou

- `lib/core/utils/clock.dart`: `Clock`, `systemClock` e `clockProvider`. Toda data de
  negócio (mês corrente, fechamento do cartão, "faz N dias do último backup", data de
  lançamento novo, carimbo do backup) passa a vir do provider.
- `EntriesRepository` recebe `now` no construtor; os parâmetros `today` continuam
  (significam "data de referência" explícita, como no formulário).
- `tool/validar.dart` ganhou a verificação "DateTime.now() só pelo relógio injetável":
  falha se aparecer `DateTime.now()` em `lib/` sem `// clock-ok: motivo` na linha.
- `tool/validar.dart` **não falhava nunca**: `main` devolvia o resultado como retorno,
  que o Dart ignora, e o CI ficava verde mesmo com verificação reprovada. Agora usa
  `exitCode`.

## Por quê

O teste do cartão que fecha dia 22 quebrou antes da 1.0 só porque rodou depois do dia 22.
Teste que depende do dia em que roda é bug. Com o relógio injetável o teste fixa "hoje" e
cobre os dois lados do fechamento sempre.

Exceções marcadas com `// clock-ok`: nome de arquivo temporário no `backup_service`
(`microsecondsSinceEpoch`) e a janela de 2 s do `DoubleBackToExit`; não são data de negócio.

## Arquivos tocados

[clock.dart](../lib/core/utils/clock.dart) ·
[entries_repository.dart](../lib/features/entries/data/entries_repository.dart) ·
[repositories.dart](../lib/core/database/repositories.dart) ·
[entry_form_screen.dart](../lib/features/entries/presentation/entry_form_screen.dart) ·
[month_screen.dart](../lib/features/entries/presentation/month_screen.dart) ·
[backup_actions.dart](../lib/features/settings/presentation/backup_actions.dart) ·
[validar.dart](../tool/validar.dart) ·
[entry_form_closing_rule_test.dart](../test/features/entries/entry_form_closing_rule_test.dart)

## Como verificar

- `flutter analyze` e `flutter test` (538 + 1 teste novo).
- `dart run tool/validar.dart; echo "exit=$?"`; para ver a trava falhar, acrescente
  `final x = DateTime.now();` em qualquer arquivo de `lib/` e rode de novo (sai com 1).

## O que não foi verificado

- Não rodei o app no aparelho nesta entrega; a cobertura é a suíte de testes.
- Só o teste do fechamento do cartão usa relógio fixo. Os demais testes que usam
  `DateTime.now()` (`home_notices`, `payment_validation`, `month_filters`,
  `data_settings`) seguem com o relógio real: são consistentes com o app, mas ainda
  não imunes a virada de mês/dia.

## Pendências / próximos passos

- Migrar os testes acima para o relógio fixo, aos poucos, quando forem tocados.
- Segue a 0034 (segurança).
