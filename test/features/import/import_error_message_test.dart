import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/domain/import_error_message.dart';

void main() {
  group('describeImportError — o erro da importação em português, com o que fazer', () {
    ImportErrorMessage of(Object e, {String during = 'ler essa aba'}) => describeImportError(e, during: during);

    test('chave recusada (401/403) manda conferir a chave na tela de IA', () {
      final m = of(LlmLocatorException.http('Groq', 401, '{"error":"invalid_api_key"}'));
      expect(m.text, contains('Não consegui ler essa aba'));
      expect(m.text, contains('chave'));
      expect(m.text, contains('Configurações'));
      expect(m.detail, contains('401'), reason: 'o detalhe técnico fica disponível');
      expect(of(LlmLocatorException.http('Groq', 403, 'x')).text, contains('chave'));
    });

    test('modelo não encontrado (404) manda trocar o modelo', () {
      final m = of(LlmLocatorException.http('Groq', 404, 'model_not_found'));
      expect(m.text, contains('modelo'));
    });

    test('limite ou sobrecarga (429/503/529) manda esperar', () {
      for (final status in [429, 503, 529]) {
        final m = of(LlmLocatorException.http('Groq', status, 'x'));
        expect(m.text, contains('Espere'), reason: '$status');
      }
    });

    test('outro erro do serviço de IA não vaza o corpo da resposta no texto principal', () {
      final m = of(LlmLocatorException.http('Groq', 500, '<html>gigante e técnico</html>'));
      expect(m.text, isNot(contains('<html>')));
      expect(m.detail, contains('<html>'));
    });

    test('falta de chave mantém a mensagem que já leva à configuração', () {
      final m = of(LlmLocatorException.noKey('Nenhuma IA configurada. Abra o menu › Configurações.'));
      expect(m.text, contains('Nenhuma IA configurada'));
      expect(m.detail, equals(null), reason: 'já é uma frase para a pessoa, sem detalhe técnico');
    });

    test('sem internet', () {
      for (final e in [const SocketException('x'), http.ClientException('x'), TimeoutException('x')]) {
        final m = of(e);
        expect(m.text, contains('internet'), reason: '${e.runtimeType}');
      }
    });

    test('tabela não encontrada pela IA: diz qual e sugere tentar de novo, não "arquivo inválido"', () {
      final m = of(const TablesNotFoundException(despesasFound: true, entradaFound: false));
      expect(m.text, contains('"Entrada de Valor"'));
      expect(m.text, contains('outra vez'));
      expect(m.text, isNot(contains('.xlsx válida')));
    });

    test('arquivo que não é uma planilha válida', () {
      final m = of(const FormatException('bad zip'), during: 'abrir o arquivo');
      expect(m.text, contains('Não consegui abrir o arquivo'));
      expect(m.text, contains('.xlsx'));
    });

    test('qualquer outro erro: frase genérica e o detalhe guardado', () {
      final m = of(StateError('algo estranho'), during: 'gravar os lançamentos');
      expect(m.text, contains('Não consegui gravar os lançamentos'));
      expect(m.detail, contains('algo estranho'));
    });
  });
}
