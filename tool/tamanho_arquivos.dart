// Limite de tamanho dos arquivos Dart escritos à mão.
//
//   lib/   avisa acima de 250 linhas e falha acima de 400
//   test/  falha acima de 500
//
// Arquivo gerado (*.g.dart, *.drift.dart, *.steps.dart, test/drift/**/generated/**)
// não conta. Quem já estava acima do limite quando a regra nasceu fica em
// tool/tamanho_excecoes.txt com um teto que SÓ ENCOLHE: passar do teto falha, e o
// arquivo que desce do limite precisa sair da lista. Arquivo novo não ganha exceção.
//
// Uso: dart run tool/tamanho_arquivos.dart   (sai com 1 se algo falhar)
import 'dart:io';

const libWarn = 250;
const libFail = 400;
const testFail = 500;

bool _generated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.drift.dart') ||
    path.endsWith('.steps.dart') ||
    RegExp(r'^test/drift/.*/generated/').hasMatch(path);

Map<String, int> _exceptions() {
  final file = File('tool/tamanho_excecoes.txt');
  if (!file.existsSync()) return {};
  final result = <String, int>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.split('#').first.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    result[parts[0]] = int.parse(parts[1]);
  }
  return result;
}

int _lines(File f) {
  final text = f.readAsStringSync();
  if (text.isEmpty) return 0;
  return '\n'.allMatches(text).length + (text.endsWith('\n') ? 0 : 1);
}

/// Devolve as falhas (vazio = tudo certo) e imprime os avisos.
List<String> check() {
  final exceptions = _exceptions();
  final failures = <String>[];
  final seen = <String>{};

  for (final root in ['lib', 'test']) {
    final limit = root == 'lib' ? libFail : testFail;
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (_generated(path)) continue;
      final n = _lines(entity);
      final ceiling = exceptions[path];
      if (ceiling != null) seen.add(path);

      if (n > limit) {
        if (ceiling == null) {
          failures.add('$path tem $n linhas (limite $limit). Divida o arquivo; não há exceção para ele.');
        } else if (n > ceiling) {
          failures.add('$path cresceu para $n linhas (teto da exceção: $ceiling). O teto só encolhe.');
        } else if (n < ceiling) {
          stdout.writeln('    aviso: $path caiu para $n linhas; baixe o teto em tamanho_excecoes.txt (era $ceiling).');
        }
      } else {
        if (ceiling != null) {
          failures.add('$path está com $n linhas, dentro do limite ($limit): tire-o de tamanho_excecoes.txt.');
        }
        if (root == 'lib' && n > libWarn) {
          stdout.writeln('    aviso: $path tem $n linhas (acima de $libWarn; falha acima de $libFail).');
        }
      }
    }
  }
  for (final path in exceptions.keys.where((p) => !seen.contains(p))) {
    failures.add('tamanho_excecoes.txt lista $path, que não existe mais: tire a linha.');
  }
  return failures;
}

void main() {
  final failures = check();
  for (final f in failures) {
    stdout.writeln('  $f');
  }
  exitCode = failures.isEmpty ? 0 : 1;
}
