import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/settings/domain/appearance.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:izifnc/features/settings/presentation/settings_screen.dart';

import '../../support/menu.dart';
import '../../support/real_fonts.dart';

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;

  // Mesma receita do widget_test.dart: streams fechadas de forma síncrona e
  // close() com limite, para o relógio falso não travar a suíte.
  setUp(() {
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  /// Sobe o app inteiro e abre Configurações › Geral.
  Future<void> openGeneral(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tourEnabledProvider.overrideWithValue(false),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Configurações fica no menu lateral (0010).
    await goViaMenu(tester, 'Configurações');
    await tester.tap(find.text('Geral'));
    await tester.pumpAndSettle();
  }

  Future<Appearance> stored() => (db.select(db.appSettings).getSingle()).then(
    (s) => Appearance(
      themeMode: AppThemeMode.fromStored(s.themeMode),
      textScale: s.textScale,
      highContrast: s.highContrast,
    ),
  );

  ThemeData currentTheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first));

  testWidgets('a tela de Configurações lista as seções e abre a Geral', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tourEnabledProvider.overrideWithValue(false),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Configurações fica no menu lateral (0010).
    await goViaMenu(tester, 'Configurações');

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Geral'), findsOneWidget);

    await tester.tap(find.text('Geral'));
    await tester.pumpAndSettle();
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Alto contraste'), findsOneWidget);
  });

  testWidgets('escolher Escuro muda o tema na hora e fica gravado', (tester) async {
    await openGeneral(tester);
    expect(currentTheme(tester).brightness, Brightness.light);

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(currentTheme(tester).brightness, Brightness.dark);
    expect((await stored()).themeMode, AppThemeMode.dark);
  });

  testWidgets('tamanho do texto multiplica o do sistema', (tester) async {
    await openGeneral(tester);
    double scaleNow() => MediaQuery.of(tester.element(find.text('Tema'))).textScaler.scale(1.0);
    expect(scaleNow(), 1.0);

    // Slider de 4 posições: um toque no fim escolhe "Muito grande".
    await tester.drag(find.byType(Slider), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(scaleNow(), 1.3);
    expect((await stored()).textScale, 1.3);
    expect(find.textContaining('Muito grande'), findsWidgets);
  });

  testWidgets('alto contraste liga e desliga', (tester) async {
    await openGeneral(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await stored()).highContrast, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await stored()).highContrast, isFalse);
  });

  testWidgets('Sobre mostra a versão e o build do app', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'IziFnc',
      packageName: 'com.getulio.izifnc',
      version: '9.8.7',
      buildNumber: '42',
      buildSignature: '',
    );
    await openGeneral(tester);
    await tester.ensureVisible(find.text('Sobre'));
    await tester.pumpAndSettle();

    expect(find.text('Versão 9.8.7 (build 42)'), findsOneWidget);
  });

  testWidgets('o dia de virada do mês se edita aqui e fica gravado', (tester) async {
    await openGeneral(tester);
    final tile = find.text('O mês começa no dia 1');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();

    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Dia'), '27');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('O mês começa no dia 27'), findsOneWidget);
    expect((await db.select(db.appSettings).getSingle()).monthStartDay, 27);
  });

  testWidgets('dia de virada fora de 1 a 31 não salva', (tester) async {
    await openGeneral(tester);
    final tile = find.text('O mês começa no dia 1');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();

    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Dia'), '32');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Um dia de 1 a 31'), findsOneWidget);
    expect((await db.select(db.appSettings).getSingle()).monthStartDay, 1);
  });

  testWidgets('a tela de contas não tem mais o dia de virada', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tourEnabledProvider.overrideWithValue(false),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    await goViaMenu(tester, 'Contas e cartões');

    expect(find.textContaining('O mês começa no dia'), findsNothing);
  });

  testWidgets('alto contraste muda mesmo as cores (mais contraste que o normal)', (tester) async {
    await openGeneral(tester);
    final normal = currentTheme(tester).colorScheme.primary;

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(currentTheme(tester).colorScheme.primary, isNot(normal));
  });
}
