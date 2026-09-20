import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../accounts/domain/account_kind.dart';
import '../../entries/data/entries_repository.dart';
import '../domain/appearance.dart';

class SettingsRepository {
  SettingsRepository(this._db, this._entries);

  final AppDatabase _db;
  final EntriesRepository _entries;

  Stream<int> watchMonthStartDay() =>
      _db.select(_db.appSettings).watchSingle().map((s) => s.monthStartDay);

  /// Muda o dia de virada. Os lançamentos de conta corrente trocam de mês na
  /// mesma transação; cartões não são afetados (usam o próprio fechamento).
  Future<void> setMonthStartDay(int day) {
    RangeError.checkValueInInterval(day, 1, 31, 'day');
    return _db.transaction(() async {
      await _db
          .update(_db.appSettings)
          .write(AppSettingsCompanion(monthStartDay: Value(day)));
      await _entries.recompute(kind: AccountKind.checking);
    });
  }

  Stream<Appearance> watchAppearance() =>
      _db.select(_db.appSettings).watchSingle().map(
        (s) => Appearance(
          themeMode: AppThemeMode.fromStored(s.themeMode),
          textScale: s.textScale,
          highContrast: s.highContrast,
        ),
      );

  Future<void> setThemeMode(AppThemeMode mode) => _db
      .update(_db.appSettings)
      .write(AppSettingsCompanion(themeMode: Value(mode.index)));

  Future<void> setTextScale(double scale) {
    if (scale < TextSize.minScale || scale > TextSize.maxScale) {
      throw RangeError.value(
        scale,
        'scale',
        'precisa estar entre ${TextSize.minScale} e ${TextSize.maxScale}',
      );
    }
    return _db
        .update(_db.appSettings)
        .write(AppSettingsCompanion(textScale: Value(scale)));
  }

  Future<void> setHighContrast(bool value) => _db
      .update(_db.appSettings)
      .write(AppSettingsCompanion(highContrast: Value(value)));

  /// Quando o backup foi exportado pela última vez; nulo = nunca.
  Stream<DateTime?> watchLastBackup() =>
      _db.select(_db.appSettings).watchSingle().map((s) => s.lastBackupAt);

  Future<void> markBackup(DateTime at) => _db
      .update(_db.appSettings)
      .write(AppSettingsCompanion(lastBackupAt: Value(at)));
}
