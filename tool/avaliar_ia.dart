// Avaliação AO VIVO dos provedores de LLM contra o corpus de planilhas.
//
//   dart run tool/avaliar_ia.dart [--providers groq,anthropic] [--repeat 3]
//                                 [--corpus docs/exemplo] [--delay-ms 4000]
//
// Para cada provedor × planilha × aba × rodada, pergunta onde ficam as tabelas e
// compara com o `.esperado.json`. Mede acerto, tentativas e latência — e serve
// para (a) comparar provedores e modelos, (b) descobrir cedo um modelo
// aposentado e (c) medir o quanto a IA generaliza para layouts novos.
//
// Chaves: variáveis de ambiente GROQ_API_KEY / ANTHROPIC_API_KEY, ou os
// arquivos _local/keys/{groq,anthropic}.txt (nunca versionados). Custa centavos
// e NÃO roda no CI (precisa de chave e a resposta de um LLM não é determinística).
//
// Sai com código 1 se a IA ERRAR (ou falhar de forma permanente) num caso NÃO marcado
// como "limite conhecido". Provedor indisponível (429/503) é apontado, mas não reprova.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:izifnc/features/import/data/anthropic_table_locator.dart';
import 'package:izifnc/features/import/data/fallback_table_locator.dart';
import 'package:izifnc/features/import/data/groq_table_locator.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

import 'corpus.dart';

/// Conta quantas vezes o provedor foi realmente chamado (o retry chama de novo).
class _Counting implements LlmTableLocator {
  _Counting(this._inner);
  final LlmTableLocator _inner;
  int calls = 0;

  @override
  String get providerName => _inner.providerName;

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) {
    calls++;
    return _inner.locate(grid, sheetName: sheetName);
  }
}

class _Result {
  _Result({
    required this.provider,
    required this.caso,
    required this.aba,
    required this.rodada,
    required this.ok,
    required this.indisponivel,
    required this.limite,
    required this.attempts,
    required this.ms,
    required this.detalhe,
  });

  final String provider;
  final String caso;
  final String aba;
  final int rodada;
  final bool ok;

  /// O provedor não respondeu (429/503/529 mesmo após o retry): não é a IA que
  /// errou, então **não reprova** o gate — só é apontado.
  final bool indisponivel;
  final bool limite;

  /// Errou a localização, ou falhou de forma permanente (chave inválida, modelo
  /// aposentado...): estes reprovam nos casos suportados.
  bool get reprova => !ok && !indisponivel && !limite;

  String get simbolo => ok ? '✓' : (limite ? '~' : (indisponivel ? '⏳' : '✗'));
  final int attempts;
  final int ms;
  final String detalhe;
}

String? _readKey(String env, String fileName) {
  final fromEnv = Platform.environment[env];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
  final file = File('_local/keys/$fileName.txt');
  if (file.existsSync()) {
    final text = file.readAsStringSync().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String _describe(TableLocation? l) => l == null ? 'null' : 'L${l.headerRow}/C${l.startCol}';

bool _same(TableLocation? a, TableLocation? b) =>
    (a == null && b == null) || (a != null && b != null && a.headerRow == b.headerRow && a.startCol == b.startCol);

Future<int> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final providers = (opt('providers') ?? 'groq,anthropic').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final repeat = int.tryParse(opt('repeat') ?? '') ?? 1;
  final delay = Duration(milliseconds: int.tryParse(opt('delay-ms') ?? '') ?? 4000);
  final corpusDirs = [
    for (var i = 0; i < args.length - 1; i++)
      if (args[i] == '--corpus') args[i + 1],
  ];

  final warnings = <String>[];
  final cases = loadCorpus(dirs: corpusDirs.isEmpty ? const [publicCorpusDir, privateCorpusDir] : corpusDirs, warnings: warnings);
  for (final w in warnings) {
    stderr.writeln('aviso: $w');
  }
  if (cases.isEmpty) {
    stderr.writeln('Nenhuma planilha no corpus. Rode: dart run tool/gerar_planilhas_exemplo.dart');
    return 2;
  }

  final client = http.Client();
  final results = <_Result>[];
  final modelOf = <String, String>{};

  for (final provider in providers) {
    final key = switch (provider) {
      'groq' => _readKey('GROQ_API_KEY', 'groq'),
      'anthropic' => _readKey('ANTHROPIC_API_KEY', 'anthropic'),
      _ => null,
    };
    if (key == null) {
      stderr.writeln('• $provider: sem chave (defina a variável de ambiente ou _local/keys/$provider.txt) — pulado.');
      continue;
    }

    for (final c in cases) {
      final workbook = c.open();
      for (final entry in c.abas.entries) {
        final grid = workbook.readSheet(entry.key);
        for (var rodada = 1; rodada <= repeat; rodada++) {
          final inner = switch (provider) {
            'groq' => GroqTableLocator(client: client, apiKey: key),
            _ => AnthropicTableLocator(client: client, apiKey: key),
          };
          modelOf[provider] = switch (inner) {
            GroqTableLocator l => l.modelName,
            AnthropicTableLocator l => l.modelName,
            _ => '?',
          };
          final counting = _Counting(inner);
          final locator = RetryingTableLocator(counting);

          final watch = Stopwatch()..start();
          var ok = false;
          var indisponivel = false;
          var detalhe = '';
          try {
            final got = await locator.locate(grid, sheetName: entry.key);
            ok = _same(got.despesasGerais, entry.value.despesasGerais) && _same(got.entradaDeValor, entry.value.entradaDeValor);
            detalhe = ok
                ? ''
                : 'esperado D=${_describe(entry.value.despesasGerais)} E=${_describe(entry.value.entradaDeValor)}; '
                      'veio D=${_describe(got.despesasGerais)} E=${_describe(got.entradaDeValor)}';
          } on LlmLocatorException catch (e) {
            indisponivel = e.retryable; // só sobra retryable se o retry esgotou
            detalhe = e.message.replaceAll(RegExp(r'\s+'), ' ');
            if (detalhe.length > 160) detalhe = '${detalhe.substring(0, 160)}…';
          }
          watch.stop();

          final r = _Result(
            provider: provider,
            caso: c.slug,
            aba: entry.key,
            rodada: rodada,
            ok: ok,
            indisponivel: indisponivel,
            limite: c.limiteConhecido,
            attempts: counting.calls,
            ms: watch.elapsedMilliseconds,
            detalhe: detalhe,
          );
          results.add(r);
          stdout.writeln(
            '${r.simbolo} ${provider.padRight(9)} ${c.slug.padRight(18)} '
            '${entry.key.padRight(6)} #$rodada  ${r.ms.toString().padLeft(5)}ms  tentativas=${r.attempts}'
            '${detalhe.isEmpty ? '' : '  $detalhe'}',
          );
          await Future<void>.delayed(delay);
        }
      }
    }
  }
  client.close();

  if (results.isEmpty) {
    stderr.writeln('Nenhum provedor avaliado (nenhuma chave encontrada).');
    return 2;
  }

  // Resumo por provedor: só os casos "suportados" contam para nota; os de
  // limite conhecido aparecem à parte.
  final report = StringBuffer();
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${now.year}-${two(now.month)}-${two(now.day)}-${two(now.hour)}${two(now.minute)}';
  report
    ..writeln('# Avaliação da IA — $stamp')
    ..writeln()
    ..writeln('Corpus: ${cases.length} planilha(s) · rodadas por caso: $repeat')
    ..writeln()
    ..writeln('| Provedor | Modelo | Acertos | Indisponível | Latência média | Tentativas médias | Limite conhecido |')
    ..writeln('|---|---|---|---|---|---|---|');

  var failed = false;
  var unavailable = 0;
  for (final provider in {for (final r in results) r.provider}) {
    final mine = results.where((r) => r.provider == provider).toList();
    final graded = mine.where((r) => !r.limite).toList();
    final hits = graded.where((r) => r.ok).length;
    final off = graded.where((r) => r.indisponivel).length;
    unavailable += off;
    if (mine.any((r) => r.reprova)) failed = true;
    final avgMs = mine.map((r) => r.ms).reduce((a, b) => a + b) ~/ mine.length;
    final avgTries = (mine.map((r) => r.attempts).reduce((a, b) => a + b) / mine.length).toStringAsFixed(2);
    final limite = mine.where((r) => r.limite).toList();
    report.writeln(
      '| $provider | ${modelOf[provider]} | $hits/${graded.length} | $off | ${avgMs}ms | $avgTries | '
      '${limite.isEmpty ? '—' : '${limite.where((r) => r.ok).length}/${limite.length} localizadas'} |',
    );
  }

  report
    ..writeln()
    ..writeln('## Casos')
    ..writeln()
    ..writeln('| | Provedor | Planilha | Aba | Rodada | Latência | Tentativas | Detalhe |')
    ..writeln('|---|---|---|---|---|---|---|---|');
  for (final r in results) {
    report.writeln(
      '| ${r.simbolo} | ${r.provider} | ${r.caso} | ${r.aba} | ${r.rodada} | '
      '${r.ms}ms | ${r.attempts} | ${r.detalhe.replaceAll('|', '\\|')} |',
    );
  }

  final outDir = Directory(opt('out') ?? '_local/eval')..createSync(recursive: true);
  final outFile = File('${outDir.path}/$stamp.md')..writeAsStringSync(report.toString());
  stdout
    ..writeln()
    ..writeln(failed ? '✗ A IA errou (ou falhou de forma permanente) em caso suportado.' : '✓ Nenhum erro em casos suportados.');
  if (unavailable > 0) {
    stdout.writeln(
      '⏳ $unavailable chamada(s) sem resposta (limite de taxa/sobrecarga, mesmo após o retry) — '
      'não contam como erro da IA; rode de novo ou aumente --delay-ms.',
    );
  }
  stdout.writeln('Relatório: ${outFile.path}');
  return failed ? 1 : 0;
}
