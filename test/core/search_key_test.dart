import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/utils/search_key.dart';

void main() {
  group('searchKey — texto comparável para busca', () {
    test('tira acentos e cedilha', () {
      expect(searchKey('Salário do 13º — São João, ação'), 'salario do 13º — sao joao, acao');
    });

    test('ignora maiúsculas', () {
      expect(searchKey('MERCADO'), 'mercado');
    });

    test('mantém o que não é letra acentuada', () {
      expect(searchKey('R\$ 12,50 #a-b_c'), 'r\$ 12,50 #a-b_c');
    });

    test('vazio continua vazio', () {
      expect(searchKey(''), '');
    });

    test('tudo o que o português acentua', () {
      expect(searchKey('áàâãä éèêë íìîï óòôõö úùûü ç ñ'), 'aaaaa eeee iiii ooooo uuuu c n');
      expect(searchKey('ÁÀÂÃÄ ÉÈÊË ÍÌÎÏ ÓÒÔÕÖ ÚÙÛÜ Ç Ñ'), 'aaaaa eeee iiii ooooo uuuu c n');
    });
  });
}
