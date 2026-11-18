import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ambrio/core/theme/app_theme.dart';

/// Razão de contraste da WCAG entre duas cores.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // Pares texto/fundo que o app realmente usa. Normal: 4,5:1; alto contraste: 7:1.
  final modes = <String, ThemeData>{
    'claro': AppTheme.light(),
    'escuro': AppTheme.dark(),
    'claro, alto contraste': AppTheme.light(highContrast: true),
    'escuro, alto contraste': AppTheme.dark(highContrast: true),
  };

  for (final entry in modes.entries) {
    final high = entry.key.contains('alto');
    final floor = high ? 7.0 : 4.5;
    final s = entry.value.colorScheme;
    final pairs = <String, (Color, Color)>{
      'texto sobre a tela': (s.onSurface, s.surface),
      'texto sobre o botão principal': (s.onPrimary, s.primary),
      'texto sobre o container principal': (
        s.onPrimaryContainer,
        s.primaryContainer,
      ),
      'texto sobre o âmbar': (s.onTertiary, s.tertiary),
      'texto sobre o container âmbar': (
        s.onTertiaryContainer,
        s.tertiaryContainer,
      ),
      'erro sobre a tela': (s.error, s.surface),
      'texto sobre o erro': (s.onError, s.error),
      'cor principal sobre a tela': (s.primary, s.surface),
      'texto secundário sobre a tela': (s.onSurfaceVariant, s.surface),
      'texto sobre o cartão': (s.onSurface, s.surfaceContainerLow),
      'texto secundário sobre o cartão': (
        s.onSurfaceVariant,
        s.surfaceContainerLow,
      ),
      'texto sobre o aviso e a seleção (âmbar claro)': (
        s.onSecondaryContainer,
        s.secondaryContainer,
      ),
      'ícone do botão + sobre o âmbar': (
        entry.value.floatingActionButtonTheme.foregroundColor!,
        entry.value.floatingActionButtonTheme.backgroundColor!,
      ),

      'texto do botão cheio (marinho sobre âmbar)': (
        entry.value.filledButtonTheme.style!.foregroundColor!.resolve({})!,
        entry.value.filledButtonTheme.style!.backgroundColor!.resolve({})!,
      ),
      'interruptor ligado: bolinha marinho sobre a trilha âmbar': (
        entry.value.switchTheme.thumbColor!.resolve({WidgetState.selected})!,
        entry.value.switchTheme.trackColor!.resolve({WidgetState.selected})!,
      ),
      'contorno marinho da barra de gasto sobre a trilha': (
        s.primary,
        s.surfaceContainerHigh,
      ),
    };
    group('contraste · ${entry.key}', () {
      pairs.forEach((name, pair) {
        test('$name ≥ ${floor.toStringAsFixed(1)}:1', () {
          final ratio = contrast(pair.$1, pair.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(floor),
            reason: '$name deu ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });
    });
  }

  test(
    'âmbar com texto branco não passa (por isso o texto sobre ele é escuro)',
    () {
      expect(contrast(Colors.white, AppTheme.amber), lessThan(3.0));
    },
  );

  // O alto contraste tem de SE VER (o autor não notou diferença na primeira versão): fundo, cartões
  // e bordas mudam de verdade, e a borda passa a ser forte e grossa.
  for (final dark in [false, true]) {
    final name = dark ? 'escuro' : 'claro';
    group('alto contraste se vê ($name)', () {
      final normal = (dark ? AppTheme.dark() : AppTheme.light());
      final hc = (dark
          ? AppTheme.dark(highContrast: true)
          : AppTheme.light(highContrast: true));

      test('o fundo e o cartão mudam', () {
        expect(hc.colorScheme.surface, isNot(normal.colorScheme.surface));
        expect(
          hc.colorScheme.surfaceContainerLow,
          isNot(normal.colorScheme.surfaceContainerLow),
        );
      });

      test('a borda é extrema (7:1 contra o fundo) e o contorno do cartão fica mais grosso', () {
        expect(
          contrast(hc.colorScheme.outline, hc.colorScheme.surface),
          greaterThanOrEqualTo(7.0),
        );
        expect(
          contrast(hc.colorScheme.outline, hc.colorScheme.surface),
          greaterThan(
            contrast(normal.colorScheme.outline, normal.colorScheme.surface) +
                2,
          ),
        );
        double width(ThemeData t) =>
            ((t.cardTheme.shape! as RoundedRectangleBorder).side).width;
        expect(width(hc), 2);
        expect(width(normal), 1);
      });

      test('o texto fica no extremo (preto ou branco)', () {
        expect(
          hc.colorScheme.onSurface,
          dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        );
      });
    });
  }
}
