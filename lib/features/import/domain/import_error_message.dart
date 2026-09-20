import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/llm_table_locator.dart';

/// O erro da importação como a pessoa lê: [text] diz o que aconteceu e o que
/// fazer; [detail] guarda o texto técnico (para quem for reportar o problema) e
/// fica em segundo plano na tela.
class ImportErrorMessage {
  const ImportErrorMessage(this.text, {this.detail});

  final String text;
  final String? detail;
}

/// Traduz [error] (o que foi capturado durante [during], ex.: "ler essa aba")
/// numa mensagem em português simples. Só o [ImportErrorMessage.text] aparece
/// direto; a exceção crua vai em [ImportErrorMessage.detail].
ImportErrorMessage describeImportError(Object error, {required String during}) {
  final prefix = 'Não consegui $during.';

  if (error is LlmLocatorException) {
    // Falta de chave já é uma frase para a pessoa, e leva à configuração.
    if (error.missingKey) return ImportErrorMessage(error.message);
    final status = int.tryParse(RegExp(r'respondeu (\d{3})').firstMatch(error.message)?.group(1) ?? '');
    final reason = switch (status) {
      401 || 403 =>
        'A chave de IA foi recusada. Confira a chave em Configurações › Inteligência '
        'artificial (o botão Testar mostra se ela funciona).',
      404 =>
        'O modelo de IA não foi encontrado. Troque o modelo em Configurações › '
        'Inteligência artificial.',
      429 || 503 || 529 =>
        'O serviço de IA está ocupado ou chegou no limite. Espere um minuto e tente de novo.',
      _ => 'O serviço de IA não respondeu como esperado. Tente de novo em instantes.',
    };
    return ImportErrorMessage('$prefix $reason', detail: error.message);
  }

  if (error is SocketException || error is http.ClientException || error is TimeoutException) {
    return ImportErrorMessage(
      '$prefix Sem conexão com a internet. A importação usa a internet só para a IA achar as tabelas.',
      detail: '$error',
    );
  }

  if (error is FormatException) {
    return ImportErrorMessage(
      '$prefix Este arquivo não parece ser uma planilha .xlsx válida. Salve a planilha como .xlsx e tente de novo.',
      detail: '$error',
    );
  }

  return ImportErrorMessage('$prefix Tente de novo; se continuar, o detalhe abaixo ajuda a entender.', detail: '$error');
}
