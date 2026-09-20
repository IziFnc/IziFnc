import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Os testes que usam o menu chamam `loadRealFonts()` (real_fonts.dart) no
// `setUpAll`: com a fonte de teste padrão, os rótulos do menu estouram.

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(DrawerButton));
  await tester.pumpAndSettle();
}

Finder menuItem(String label) =>
    find.descendant(of: find.byType(NavigationDrawer), matching: find.text(label));

/// Abre o menu e vai para [label].
Future<void> goViaMenu(WidgetTester tester, String label) async {
  await openMenu(tester);
  await tester.tap(menuItem(label));
  await tester.pumpAndSettle();
}
