// Validação antes de publicar.
//
//   dart run tool/validar.dart          # análise, testes e verificações de segurança
//   dart run tool/validar.dart --live   # + avaliação ao vivo dos provedores de LLM
//
// Sai com código 1 se qualquer verificação falhar. É o mesmo script que o CI
// (`.github/workflows/ci.yml`) roda a cada push — sem `--live`, porque o CI não
// tem chave de API nem deve ter.
import 'dart:convert';
import 'dart:io';

/// Padrões de chave de API dos provedores usados. Exigem uma cauda longa de
/// caracteres de chave: assim o texto destes próprios padrões (e os placeholders
/// dos testes, como "chave-de-teste") não disparam.
final _secretPatterns = <String, RegExp>{
  'chave da Groq': RegExp(r'gsk_[A-Za-z0-9]{40,}'),
  'chave da Anthropic': RegExp(r'sk-ant-[A-Za-z0-9_\-]{30,}'),
  'chave do Google/Gemini': RegExp(r'AIza[0-9A-Za-z_\-]{30,}'),
};

/// Arquivos que nunca devem estar no git: segredos e dados do usuário.
final _forbiddenTracked = <RegExp>[
  RegExp(r'(^|/)\.env(\..*)?$'),
  RegExp(r'(^|/)key\.properties$'),
  RegExp(r'\.(jks|keystore)$'),
  RegExp(r'\.(sqlite|sqlite3|db)$'),
];

class _Check {
  _Check(this.name, this.run);

  final String name;

  /// `null` = passou; texto = motivo da falha.
  final Future<String?> Function() run;
}

Future<ProcessResult> _run(String exe, List<String> args) => Process.run(
  exe,
  args,
  // `flutter` é um .bat no Windows; sem shell, o Process não o encontra.
  runInShell: Platform.isWindows,
  stdoutEncoding: const Utf8Codec(allowMalformed: true),
  stderrEncoding: const Utf8Codec(allowMalformed: true),
);

String _tail(String text, [int lines = 12]) {
  final all = text.trim().split('\n');
  return all.skip(all.length > lines ? all.length - lines : 0).join('\n');
}

Future<String?> _flutter(List<String> args) async {
  final r = await _run('flutter', args);
  return r.exitCode == 0 ? null : 'flutter ${args.join(' ')} saiu com ${r.exitCode}:\n${_tail('${r.stdout}\n${r.stderr}')}';
}

Future<List<String>> _trackedFiles() async {
  final r = await _run('git', ['ls-files']);
  return r.exitCode == 0 ? const LineSplitter().convert('${r.stdout}').where((l) => l.isNotEmpty).toList() : [];
}

/// Procura chaves no que está versionado agora.
Future<String?> _secretsInTrackedFiles() async {
  const binary = {'.xlsx', '.png', '.jpg', '.jpeg', '.ico', '.jar', '.zip', '.sqlite', '.ttf', '.otf'};
  final hits = <String>[];
  for (final path in await _trackedFiles()) {
    if (binary.any(path.toLowerCase().endsWith)) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    final text = const Utf8Codec(allowMalformed: true).decode(file.readAsBytesSync());
    _secretPatterns.forEach((name, re) {
      if (re.hasMatch(text)) hits.add('$path: $name');
    });
  }
  return hits.isEmpty ? null : 'Possível chave em arquivo versionado:\n  ${hits.join('\n  ')}';
}

/// Procura chaves em **todo o histórico** de **todas** as branches: um segredo
/// apagado num commit posterior continua no histórico, e é ele que vaza no push.
Future<String?> _secretsInHistory() async {
  final r = await _run('git', ['log', '--all', '-p', '--no-color']);
  if (r.exitCode != 0) return 'git log falhou: ${_tail('${r.stderr}')}';
  final text = '${r.stdout}';
  final hits = <String>[
    for (final e in _secretPatterns.entries)
      if (e.value.hasMatch(text)) e.key,
  ];
  return hits.isEmpty ? null : 'Possível chave no histórico do git (${hits.join(', ')}). Reescrever o histórico antes de publicar.';
}

/// `/_local/` guarda chaves, planilhas reais e bancos de teste: nunca versionado.
Future<String?> _localNotTracked() async {
  final r = await _run('git', ['ls-files', '_local']);
  final files = '${r.stdout}'.trim();
  return files.isEmpty ? null : '_local/ está versionado:\n$files';
}

Future<String?> _forbiddenFiles() async {
  final bad = <String>[];
  for (final path in await _trackedFiles()) {
    if (_forbiddenTracked.any((re) => re.hasMatch(path))) bad.add(path);
    // Planilha só é aceita no corpus fictício; a real nunca sobe.
    if (path.toLowerCase().endsWith('.xlsx') && !path.startsWith('docs/exemplo/')) bad.add(path);
  }
  return bad.isEmpty ? null : 'Arquivos que não deveriam estar no git:\n  ${bad.join('\n  ')}';
}

/// Só os manifestos de debug/profile trazem INTERNET por padrão; sem esta linha
/// no principal, um APK release falha em toda importação (a chamada ao LLM é bloqueada).
Future<String?> _internetInMainManifest() async {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) return 'android/app/src/main/AndroidManifest.xml não existe.';
  return file.readAsStringSync().contains('android.permission.INTERNET')
      ? null
      : 'O manifesto principal não declara android.permission.INTERNET.';
}

Future<String?> _live() async {
  final p = await Process.start(
    'dart',
    ['run', 'tool/avaliar_ia.dart'],
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  return await p.exitCode == 0 ? null : 'A avaliação ao vivo reprovou (veja a saída acima).';
}

Future<int> main(List<String> args) async {
  final checks = [
    _Check('flutter analyze', () => _flutter(['analyze'])),
    _Check('flutter test (inclui o corpus de planilhas)', () => _flutter(['test'])),
    _Check('nenhuma chave de API em arquivo versionado', _secretsInTrackedFiles),
    _Check('nenhuma chave de API no histórico (todas as branches)', _secretsInHistory),
    _Check('_local/ fora do git', _localNotTracked),
    _Check('sem .env, keystore, banco ou planilha real versionados', _forbiddenFiles),
    _Check('INTERNET no manifesto principal do Android', _internetInMainManifest),
    if (args.contains('--live')) _Check('avaliação ao vivo dos provedores', _live),
  ];

  var failed = 0;
  for (final check in checks) {
    stdout.write('… ${check.name}');
    final problem = await check.run();
    stdout.writeln('\r${problem == null ? '✓' : '✗'} ${check.name}   ');
    if (problem != null) {
      failed++;
      stdout.writeln(problem.split('\n').map((l) => '    $l').join('\n'));
    }
  }

  stdout.writeln(failed == 0 ? '\nTudo certo — pode publicar.' : '\n$failed verificação(ões) falharam.');
  return failed == 0 ? 0 : 1;
}
