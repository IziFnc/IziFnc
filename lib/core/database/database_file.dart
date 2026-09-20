import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// O arquivo do banco do IziFnc no aparelho.
///
/// É o **mesmo** caminho que o `drift_flutter` escolhia sozinho
/// (`<documentos>/izifnc.sqlite`): quem já usava o app continua com os dados.
/// Fica num lugar só porque o banco e o backup precisam concordar sobre ele.
Future<File> databaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}${Platform.pathSeparator}izifnc.sqlite');
}
