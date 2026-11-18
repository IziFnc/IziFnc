import 'package:flutter/material.dart';

/// Tema do app, "Tinta & âmbar" (feat 0043 e 0047): as cores da logo, de verdade.
///
/// A logo é marinho puro com um disco de âmbar. Gerar o tema só de uma semente
/// (`ColorScheme.fromSeed`) deixava tudo lavanda e azul-acinzentado e o âmbar
/// quase sumia; agora as cores que se veem (principal, superfícies, acento) vêm
/// de **tokens** daqui e só o resto (erro, inversos) vem do gerador:
///
/// * **marinho** `#1B3A5C` é a cor principal (botões, títulos, ícones);
/// * **papel** quente (creme) nas superfícies do claro e **tinta** azul-escura no
///   escuro, em vez de cinza azulado;
/// * **âmbar** `#E8A317` é o acento: botão +, seleção ativa, avisos. Texto sobre
///   âmbar é sempre escuro (branco não passa de 2,2:1).
///
/// A trava de contraste está em `test/core/theme/contrast_test.dart`.
abstract final class AppTheme {
  static const Color navy = Color(0xFF1B3A5C);
  static const Color amber = Color(0xFFE8A317);

  /// Mantido para quem referencia a semente da marca.
  static const Color seed = navy;

  /// [highContrast] empurra textos, bordas e a cor principal para os extremos
  /// (acessibilidade), mantendo a identidade.
  static ThemeData light({bool highContrast = false}) =>
      _build(Brightness.light, highContrast);
  static ThemeData dark({bool highContrast = false}) =>
      _build(Brightness.dark, highContrast);

  static ColorScheme _lightScheme(bool hc) {
    final base = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
    );
    final scheme = base.copyWith(
      primary: hc ? const Color(0xFF10263F) : navy,
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: hc ? const Color(0xFFD3E1F2) : const Color(0xFFDDE5EE),
      onPrimaryContainer: hc
          ? const Color(0xFF000000)
          : const Color(0xFF0F2742),
      secondary: const Color(0xFF55606C),
      onSecondary: const Color(0xFFFFFFFF),
      // Seleção e avisos: âmbar claro, o mesmo tom do disco da logo.
      secondaryContainer: hc
          ? const Color(0xFFFFD66B)
          : const Color(0xFFF6E3B4),
      onSecondaryContainer: hc
          ? const Color(0xFF000000)
          : const Color(0xFF2E2100),
      tertiary: amber,
      onTertiary: const Color(0xFF241A00),
      tertiaryContainer: const Color(0xFFFFDF9E),
      onTertiaryContainer: const Color(0xFF241A00),
      // Alto contraste: fundo e cartões brancos de verdade, bordas pretas (a diferença se vê).
      surface: hc ? const Color(0xFFFFFFFF) : const Color(0xFFF7F5EF),
      surfaceDim: hc ? const Color(0xFFE6E6E6) : const Color(0xFFDEDACD),
      surfaceBright: hc ? const Color(0xFFFFFFFF) : const Color(0xFFFBFAF6),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: hc
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFF2EFE6),
      surfaceContainer: hc ? const Color(0xFFF2F2F2) : const Color(0xFFEDE9DD),
      surfaceContainerHigh: hc
          ? const Color(0xFFD9D9D9)
          : const Color(0xFFE7E2D4),
      surfaceContainerHighest: hc
          ? const Color(0xFFCCCCCC)
          : const Color(0xFFE1DCCC),
      onSurface: hc ? const Color(0xFF000000) : const Color(0xFF1C1B17),
      onSurfaceVariant: hc ? const Color(0xFF1A1A1A) : const Color(0xFF4D4A40),
      outline: hc ? const Color(0xFF000000) : const Color(0xFF7D7968),
      outlineVariant: hc ? const Color(0xFF000000) : const Color(0xFFCFC9B6),
      error: hc ? const Color(0xFF8C0009) : base.error,
      onError: const Color(0xFFFFFFFF),
      surfaceTint: Colors.transparent,
    );
    return scheme;
  }

  static ColorScheme _darkScheme(bool hc) {
    final base = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      primary: hc ? const Color(0xFFBBD0EC) : const Color(0xFF9DB8E0),
      onPrimary: const Color(0xFF0E2540),
      primaryContainer: hc ? const Color(0xFF2A4C7A) : const Color(0xFF1F3A5E),
      onPrimaryContainer: hc
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFD6E3F7),
      secondary: const Color(0xFFB4BFCC),
      onSecondary: const Color(0xFF1B2530),
      secondaryContainer: hc
          ? const Color(0xFF6B5200)
          : const Color(0xFF4A3A0E),
      onSecondaryContainer: hc
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFFFE2A3),
      tertiary: amber,
      onTertiary: const Color(0xFF241A00),
      tertiaryContainer: const Color(0xFF5C4300),
      onTertiaryContainer: const Color(0xFFFFDF9E),
      // Alto contraste: fundo preto de verdade, bordas brancas.
      surface: hc ? const Color(0xFF000000) : const Color(0xFF0F1620),
      surfaceDim: hc ? const Color(0xFF000000) : const Color(0xFF0B1119),
      surfaceBright: hc ? const Color(0xFF2B2B2B) : const Color(0xFF2A3547),
      surfaceContainerLowest: hc
          ? const Color(0xFF000000)
          : const Color(0xFF0A0F16),
      surfaceContainerLow: hc
          ? const Color(0xFF000000)
          : const Color(0xFF141C27),
      surfaceContainer: hc ? const Color(0xFF111111) : const Color(0xFF182231),
      surfaceContainerHigh: hc
          ? const Color(0xFF2A2A2A)
          : const Color(0xFF1E2A3B),
      surfaceContainerHighest: hc
          ? const Color(0xFF3A3A3A)
          : const Color(0xFF263449),
      onSurface: hc ? const Color(0xFFFFFFFF) : const Color(0xFFE3E6EB),
      onSurfaceVariant: hc ? const Color(0xFFF2F2F2) : const Color(0xFFB8C0CC),
      outline: hc ? const Color(0xFFFFFFFF) : const Color(0xFF8A94A3),
      outlineVariant: hc ? const Color(0xFFFFFFFF) : const Color(0xFF3A4656),
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _build(Brightness brightness, bool highContrast) {
    final light = brightness == Brightness.light;
    final scheme = light
        ? _lightScheme(highContrast)
        : _darkScheme(highContrast);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: amber, width: 2)),
      ),
      // O botão + é a moeda de âmbar da logo, com o marinho por cima.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: amber,
        foregroundColor: highContrast ? const Color(0xFF0A1626) : navy,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant,
            width: highContrast ? 2 : 1,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: highContrast ? 2 : null,
      ),
      outlinedButtonTheme: highContrast
          ? OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: scheme.outline, width: 2),
              ),
            )
          : null,
      segmentedButtonTheme: highContrast
          ? SegmentedButtonThemeData(
              style: SegmentedButton.styleFrom(
                side: BorderSide(color: scheme.outline, width: 2),
              ),
            )
          : null,
      inputDecorationTheme: highContrast
          ? InputDecorationTheme(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: scheme.outline, width: 2),
              ),
            )
          : null,
      // Âmbar nas ações (o disco da logo onde a pessoa toca): botão cheio, interruptor e caixa
      // de marcar, sempre com o marinho por cima ou ao redor (âmbar sozinho sobre papel dá 2:1).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: amber,
          foregroundColor: highContrast ? const Color(0xFF0A1626) : navy,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (highContrast ? const Color(0xFF0A1626) : navy)
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? amber
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? navy : scheme.outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? amber : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(navy),
        side: BorderSide(color: scheme.outline, width: 2),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
      ),
    );
  }
}
