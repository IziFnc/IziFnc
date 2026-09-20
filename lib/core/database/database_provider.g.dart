// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Instância única do banco para todo o app.
///
/// `keepAlive` porque abrir e fechar a conexão a cada tela seria desperdício —
/// o banco vive enquanto o app viver. Nos testes, sobrescreva este provider com
/// um `AppDatabase(NativeDatabase.memory())`.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// Instância única do banco para todo o app.
///
/// `keepAlive` porque abrir e fechar a conexão a cada tela seria desperdício —
/// o banco vive enquanto o app viver. Nos testes, sobrescreva este provider com
/// um `AppDatabase(NativeDatabase.memory())`.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// Instância única do banco para todo o app.
  ///
  /// `keepAlive` porque abrir e fechar a conexão a cada tela seria desperdício —
  /// o banco vive enquanto o app viver. Nos testes, sobrescreva este provider com
  /// um `AppDatabase(NativeDatabase.memory())`.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'ae24fc93aae16c2c29cad20a955870623a418d29';
