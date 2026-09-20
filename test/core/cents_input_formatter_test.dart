import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/utils/cents_input_formatter.dart';

void main() {
  final formatter = CentsInputFormatter();
  const nbsp = ' ';

  String type(String previous, String next) => formatter
      .formatEditUpdate(
        TextEditingValue(text: previous),
        TextEditingValue(text: next),
      )
      .text;

  test('digitar anda pelos centavos', () {
    expect(type('', '1'), 'R\$${nbsp}0,01');
    expect(type('R\$${nbsp}0,01', 'R\$${nbsp}0,012'), 'R\$${nbsp}0,12');
    expect(type('R\$${nbsp}0,12', 'R\$${nbsp}0,123'), 'R\$${nbsp}1,23');
    expect(type('R\$${nbsp}1,23', 'R\$${nbsp}1,234'), 'R\$${nbsp}12,34');
  });

  test('apagar volta pelos centavos até esvaziar', () {
    expect(type('R\$${nbsp}12,34', 'R\$${nbsp}12,3'), 'R\$${nbsp}1,23');
    expect(type('R\$${nbsp}0,01', 'R\$${nbsp}0,0'), '');
  });

  test('colar texto com separadores aproveita só os dígitos', () {
    expect(type('', '1.234,56'), 'R\$${nbsp}1.234,56');
  });

  test('ignora letras e sinal de menos', () {
    expect(type('', '-12a'), 'R\$${nbsp}0,12');
  });

  test('recusa passar do limite de dígitos', () {
    final full = CentsInputFormatter.format(999999999999);
    expect(type(full, '${full}9'), full);
  });

  test('parse devolve centavos', () {
    expect(CentsInputFormatter.parse('R\$${nbsp}1.234,56'), 123456);
    expect(CentsInputFormatter.parse(''), 0);
  });

  test('format de zero é vazio', () {
    expect(CentsInputFormatter.format(0), '');
  });
}
