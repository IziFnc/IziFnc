import 'package:flutter_riverpod/flutter_riverpod.dart';

/// De onde vem "agora".
typedef Clock = DateTime Function();

/// O relógio de verdade. É o **único** lugar de `lib/` onde `DateTime.now()` vale
/// para data de negócio; `tool/validar.dart` falha se aparecer outro (um uso que
/// não é data de negócio, como nome de arquivo temporário, leva o comentário
/// `// clock-ok: <motivo>` na própria linha).
DateTime systemClock() => DateTime.now();

/// O "agora" de tudo que é data de negócio: o mês corrente, o fechamento do
/// cartão, "faz N dias do último backup", a data de um lançamento novo. Os
/// testes trocam por um relógio fixo com `clockProvider.overrideWithValue(...)`,
/// em vez de torcer para rodarem num dia do mês que não mude o resultado (um
/// teste de cartão que fecha dia 22 quebrava a partir do dia 22).
final clockProvider = Provider<Clock>((ref) => systemClock);
