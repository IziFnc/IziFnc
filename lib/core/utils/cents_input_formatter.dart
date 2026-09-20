import 'package:flutter/services.dart';

import 'formatters.dart';

/// Campo de valor em que se digita só números e o valor "anda" pelos centavos,
/// como em app de banco: `1` → R$ 0,01 · `12` → R$ 0,12 · `1234` → R$ 12,34.
///
/// Evita o usuário ter que achar a vírgula no teclado e nunca produz `double`.
/// Leia o valor com [CentsInputFormatter.parse].
class CentsInputFormatter extends TextInputFormatter {
  /// Até R$ 9.999.999.999,99 — sobra para finanças pessoais e cabe folgado
  /// em `int` de 64 bits.
  static const int maxDigits = 12;

  /// Valor em centavos do texto do campo. Campo vazio vale 0.
  static int parse(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }

  /// Texto inicial do campo para um valor já existente (edição).
  static String format(int cents) => cents == 0 ? '' : Formatters.money(cents);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) return oldValue;

    // Zero vira campo vazio, senão apagar tudo trava em "R$ 0,00".
    final text = format(parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
