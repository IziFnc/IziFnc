import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

/// Onde procurar planilhas de teste: as fictícias (versionadas) e as reais
/// (privadas, nunca versionadas — `/_local/` está no `.gitignore`).
const publicCorpusDir = 'docs/exemplo';
const privateCorpusDir = '_local/planilhas';

/// O que se espera de uma aba: onde estão as tabelas e o que o leitor
/// determinístico deve extrair delas.
class SheetExpectation {
  const SheetExpectation({
    required this.despesasGerais,
    required this.entradaDeValor,
    required this.contagens,
    required this.totaisCents,
  });

  factory SheetExpectation.fromJson(Map<String, Object?> json) {
    TableLocation? loc(Object? v) => v is Map
        ? TableLocation(headerRow: v['headerRow']! as int, startCol: v['startCol']! as int)
        : null;
    Map<String, int> ints(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries) e.key as String: e.value as int,
    };
    return SheetExpectation(
      despesasGerais: loc(json['despesasGerais']),
      entradaDeValor: loc(json['entradaDeValor']),
      contagens: ints(json['contagens']),
      totaisCents: ints(json['totaisCents']),
    );
  }

  final TableLocation? despesasGerais;
  final TableLocation? entradaDeValor;

  /// despesas, entradas, transfers, billPayments, mirrorsConsumed, rowErrors.
  final Map<String, int> contagens;

  /// despesas, entradas, transfers, billPayments (em centavos).
  final Map<String, int> totaisCents;

  TableLocations get locations => TableLocations(
    despesasGerais: despesasGerais,
    entradaDeValor: entradaDeValor,
  );
}

/// Uma planilha do corpus, com a verdade esperada de cada aba.
class CorpusCase {
  const CorpusCase({
    required this.slug,
    required this.file,
    required this.descricao,
    required this.limiteConhecido,
    required this.privado,
    required this.abas,
  });

  final String slug;
  final File file;
  final String descricao;

  /// O leitor determinístico não dá conta deste layout: documenta um limite.
  final bool limiteConhecido;

  /// Vem de `_local/planilhas/` — dados reais, nunca sobem para o git.
  final bool privado;
  final Map<String, SheetExpectation> abas;

  Uint8List readBytes() => file.readAsBytesSync();
  XlsxWorkbook open() => XlsxWorkbook.open(readBytes());
}

/// Carrega todo `*.xlsx` que tenha um `*.esperado.json` ao lado. Planilha sem
/// o JSON é ignorada e listada em [warnings] (sem verdade esperada não há o que conferir).
List<CorpusCase> loadCorpus({
  List<String> dirs = const [publicCorpusDir, privateCorpusDir],
  List<String>? warnings,
}) {
  final cases = <CorpusCase>[];
  for (final dirPath in dirs) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.xlsx')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final base = file.path.substring(0, file.path.length - '.xlsx'.length);
      final expectedFile = File('$base.esperado.json');
      if (!expectedFile.existsSync()) {
        warnings?.add('${file.path}: sem ${expectedFile.uri.pathSegments.last} — ignorada.');
        continue;
      }
      final json = jsonDecode(expectedFile.readAsStringSync()) as Map<String, Object?>;
      final abas = (json['abas'] as Map<String, Object?>).map(
        (name, v) => MapEntry(name, SheetExpectation.fromJson(v! as Map<String, Object?>)),
      );
      cases.add(
        CorpusCase(
          slug: base.split(RegExp(r'[\\/]')).last,
          file: file,
          descricao: (json['descricao'] as String?) ?? '',
          limiteConhecido: (json['limiteConhecido'] as bool?) ?? false,
          privado: dirPath == privateCorpusDir,
          abas: abas,
        ),
      );
    }
  }
  return cases;
}
