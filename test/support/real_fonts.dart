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
  final fonts = _findFonts();
  final roboto = FontLoader('Roboto');
  for (final path in fonts.roboto) {
    roboto.addFont(_read(path));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')..addFont(_read(fonts.icons));
  await icons.load();
}

Future<ByteData> _read(String path) async {
  return ByteData.sublistView(await File(path).readAsBytes());
}

class _Fonts {
  const _Fonts(this.roboto, this.icons);
  final List<String> roboto;
  final String icons;
}

/// Onde ficam as fontes. A pasta `material_fonts` só existe depois que o Flutter
/// compilou algo para o aparelho (é o caso de uma máquina de desenvolvimento);
/// no CI, que só roda testes, ela não existe. Aí cai na Roboto que vem junto do
/// Dart SDK (recursos do DevTools): mesma família, mas sem o itálico, que então
/// usa o regular. Medidas de texto idênticas nos pesos que as telas usam.
_Fonts _findFonts() {
  final roots = <String>[];
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) roots.add(fromEnv);
  // Sobe a partir do executável do testador
  // (…/bin/cache/artifacts/engine/<so>/flutter_tester).
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    roots.add(dir.path);
    dir = dir.parent;
  }

  for (final root in roots) {
    final material = '$root/bin/cache/artifacts/material_fonts';
    if (File('$material/roboto-regular.ttf').existsSync()) {
      return _Fonts([
        for (final n in const ['light', 'regular', 'medium', 'bold', 'italic']) '$material/roboto-$n.ttf',
      ], '$material/materialicons-regular.otf');
    }
  }
  for (final root in roots) {
    final devtools = '$root/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts';
    if (File('$devtools/Roboto/Roboto-Regular.ttf').existsSync()) {
      return _Fonts([
        for (final n in const ['Light', 'Regular', 'Medium', 'Bold', 'Regular']) '$devtools/Roboto/Roboto-$n.ttf',
      ], '$devtools/MaterialIcons-Regular.otf');
    }
  }
  throw StateError(
    'Fonte Roboto do SDK não encontrada (procurei material_fonts e o DevTools do Dart SDK '
    'a partir de: ${roots.join(', ')}). Defina FLUTTER_ROOT com a pasta do Flutter.',
  );
}
