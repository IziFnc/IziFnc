import 'package:flutter/material.dart' show ThemeMode;

/// Qual tema o app usa.
///
/// Gravado no banco como o **índice** (0/1/2): não reordenar nem inserir no meio
/// sem migração.
enum AppThemeMode {
  system('Sistema'),
  light('Claro'),
  dark('Escuro');

  const AppThemeMode(this.label);
  final String label;

  ThemeMode get flutter => switch (this) {
    system => ThemeMode.system,
    light => ThemeMode.light,
    dark => ThemeMode.dark,
  };

  /// Valor desconhecido (banco de outra versão, dado corrompido) vira
  /// "sistema" em vez de derrubar o app na abertura.
  static AppThemeMode fromStored(int value) =>
      value >= 0 && value < values.length ? values[value] : system;
}

/// Tamanho do texto oferecido ao usuário. Multiplica o tamanho que o sistema já
/// aplica (não o substitui).
enum TextSize {
  small('Pequeno', 0.85),
  normal('Padrão', 1.0),
  large('Grande', 1.15),
  veryLarge('Muito grande', 1.3);

  const TextSize(this.label, this.scale);
  final String label;
  final double scale;

  /// Faixa aceita ao gravar (o banco guarda o número, não a opção).
  static const double minScale = 0.8;
  static const double maxScale = 2.0;

  /// A opção mais próxima de um multiplicador guardado.
  static TextSize nearest(double scale) => values.reduce(
    (a, b) => (a.scale - scale).abs() <= (b.scale - scale).abs() ? a : b,
  );
}

/// Preferências de aparência e acessibilidade.
class Appearance {
  const Appearance({
    this.themeMode = AppThemeMode.system,
    this.textScale = 1.0,
    this.highContrast = false,
  });

  final AppThemeMode themeMode;
  final double textScale;
  final bool highContrast;

  @override
  bool operator ==(Object other) =>
      other is Appearance &&
      other.themeMode == themeMode &&
      other.textScale == textScale &&
      other.highContrast == highContrast;

  @override
  int get hashCode => Object.hash(themeMode, textScale, highContrast);
}
