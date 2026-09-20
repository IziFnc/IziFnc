import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';

/// Passeio de fumaça no aparelho (feat 0016): o caminho que todo usuário faz na
/// primeira vez, com a renderização e a fonte de verdade do Android.
///
/// Roda no emulador ou celular, **não** no `flutter test` comum:
///
///     flutter test integration_test -d emulator-5554
///
/// Usa um banco **em memória**: não toca nos dados do app instalado.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  testWidgets('cria conta, lança, busca e abre Configurações', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Primeira conta.
    expect(find.text('Cadastre sua primeira conta'), findsOneWidget);
    await tester.tap(find.text('Cadastrar conta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Bradesco');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Novo lançamento'), findsOneWidget);

    // 2. Uma despesa.
    await tester.tap(find.byTooltip('Novo lançamento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '1234');
    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Padaria São João');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Padaria São João'), findsOneWidget);

    // 3. Busca sem acento acha; texto que não existe esconde.
    final search = find.widgetWithText(TextField, 'Buscar lançamentos');
    await tester.enterText(search, 'sao joao');
    await tester.pumpAndSettle();
    expect(find.text('Padaria São João'), findsOneWidget);
    await tester.enterText(search, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Padaria São João'), findsNothing);
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Padaria São João'), findsOneWidget);

    // 4. Menu → Configurações → Geral (mostra a versão).
    await tester.tap(find.byType(DrawerButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(NavigationDrawer), matching: find.text('Configurações')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geral'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sobre'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Versão '), findsOneWidget);
  });
}
