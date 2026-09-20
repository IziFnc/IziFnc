import 'package:flutter/material.dart';

/// Tema do IziFnc, derivado de uma única cor-semente.
///
/// Verde por ser a cor que o usuário associa a dinheiro em dia; o `ColorScheme`
/// gerado a partir dela cuida de contraste e das variantes claro/escuro.
abstract final class AppTheme {
  static const Color seed = Color(0xFF00875A);

  /// [highContrast] usa o nível máximo de contraste do Material 3
  /// (acessibilidade), mantendo a mesma cor-semente.
  static ThemeData light({bool highContrast = false}) =>
      _build(Brightness.light, highContrast);
  static ThemeData dark({bool highContrast = false}) =>
      _build(Brightness.dark, highContrast);

  static ThemeData _build(Brightness brightness, bool highContrast) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
