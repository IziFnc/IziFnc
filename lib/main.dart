import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `DateFormat` com locale explícito exige os símbolos de data carregados
  // antes do primeiro uso; sem isso, qualquer formatação pt-BR lança em runtime.
  await initializeDateFormatting('pt_BR');

  runApp(const ProviderScope(child: IziFncApp()));
}
