import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/settings/data/settings_repository.dart';
import 'package:izifnc/features/settings/domain/appearance.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepository(db, EntriesRepository(db));
  });
  tearDown(() => db.close());

  test('padrão: segue o sistema, texto normal, contraste normal', () async {
    final a = await settings.watchAppearance().first;
    expect(a.themeMode, AppThemeMode.system);
    expect(a.textScale, 1.0);
    expect(a.highContrast, isFalse);
  });

  test('cada ajuste é gravado sem mexer nos outros', () async {
    await settings.setThemeMode(AppThemeMode.dark);
    await settings.setTextScale(1.3);
    await settings.setHighContrast(true);

    final a = await settings.watchAppearance().first;
    expect(a.themeMode, AppThemeMode.dark);
    expect(a.textScale, 1.3);
    expect(a.highContrast, isTrue);
    expect(await settings.watchMonthStartDay().first, 1, reason: 'o resto fica como estava');

    await settings.setThemeMode(AppThemeMode.light);
    expect((await settings.watchAppearance().first).textScale, 1.3);
  });

  test('o stream avisa quando muda', () async {
    final seen = <AppThemeMode>[];
    final sub = settings.watchAppearance().listen((a) => seen.add(a.themeMode));
    await pumpEventQueue();
    await settings.setThemeMode(AppThemeMode.light);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [AppThemeMode.system, AppThemeMode.light]);
  });

  test('tamanho de texto fora da faixa é recusado', () async {
    expect(() => settings.setTextScale(0.2), throwsRangeError);
    expect(() => settings.setTextScale(5), throwsRangeError);
  });

  group('AppThemeMode', () {
    test('mapeia para o ThemeMode do Flutter', () {
      expect(AppThemeMode.system.flutter, ThemeMode.system);
      expect(AppThemeMode.light.flutter, ThemeMode.light);
      expect(AppThemeMode.dark.flutter, ThemeMode.dark);
    });

    test('valor gravado desconhecido cai em "sistema" em vez de quebrar', () {
      expect(AppThemeMode.fromStored(99), AppThemeMode.system);
      expect(AppThemeMode.fromStored(-1), AppThemeMode.system);
      expect(AppThemeMode.fromStored(2), AppThemeMode.dark);
    });
  });

  group('TextSize', () {
    test('cada opção tem um multiplicador e o mais próximo é escolhido', () {
      expect(TextSize.normal.scale, 1.0);
      expect(TextSize.nearest(1.0), TextSize.normal);
      expect(TextSize.nearest(1.28), TextSize.veryLarge);
      expect(TextSize.nearest(0.5), TextSize.small);
    });
  });
}
