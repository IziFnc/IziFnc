// Gera o PRIVACIDADE.md da raiz a partir do texto que o app mostra
// (lib/features/settings/domain/privacy_text.dart), para os dois nunca
// divergirem. Um teste confere que o arquivo está em dia.
//
//   dart run tool/gerar_privacidade.dart
import 'dart:io';

import 'package:izifnc/features/settings/domain/privacy_text.dart';

void main() {
  File('PRIVACIDADE.md').writeAsStringSync(privacyMarkdown());
  stdout.writeln('PRIVACIDADE.md gerado (versão $kPrivacyVersion).');
}
