import 'dart:io';

import 'package:flutter/services.dart';

/// Carrega a Roboto de verdade (a que vem no SDK do Flutter) no lugar da Ahem.
///
/// No `flutter test` todo texto usa a Ahem, em que **cada letra tem a largura
/// do corpo**: rótulos que cabem no celular estouram no teste (falso overflow) e,
/// pior, o contrário nunca aparece. Com a Roboto — a fonte que o Android usa
/// aqui — a medida do texto é a de verdade, e um overflow no teste é um
/// overflow no aparelho.
///
/// Chamar em `setUpAll`, antes de subir qualquer widget.
Future<void> loadRealFonts() async {
  final dir = _materialFontsDir();
  final roboto = FontLoader('Roboto');
  for (final name in const [
    'roboto-light',
    'roboto-regular',
    'roboto-medium',
    'roboto-bold',
    'roboto-italic',
  ]) {
    roboto.addFont(_read('$dir/$name.ttf'));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(_read('$dir/materialicons-regular.otf'));
  await icons.load();
}

Future<ByteData> _read(String path) async {
  return ByteData.sublistView(await File(path).readAsBytes());
}

String _materialFontsDir() {
  const suffix = 'bin/cache/artifacts/material_fonts';
  final candidates = <String>[];

  // O `flutter test` repassa a raiz do SDK; se faltar, sobe a partir do
  // executável do testador (…/bin/cache/artifacts/engine/<so>/flutter_tester).
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) candidates.add('$fromEnv/$suffix');

  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidates.add('${dir.path}/$suffix');
    dir = dir.parent;
  }

  for (final c in candidates) {
    if (File('$c/roboto-regular.ttf').existsSync()) return c;
  }
  throw StateError(
    'Fonte Roboto do SDK não encontrada. Procurei em:\n${candidates.join('\n')}\n'
    'Defina FLUTTER_ROOT com a pasta do Flutter (a que contém bin/cache).',
  );
}
