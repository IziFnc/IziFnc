// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// O serviço de backup: os arquivos temporários e as cópias de segurança ficam
/// numa pasta própria, dentro dos dados do app.

@ProviderFor(backupService)
final backupServiceProvider = BackupServiceProvider._();

/// O serviço de backup: os arquivos temporários e as cópias de segurança ficam
/// numa pasta própria, dentro dos dados do app.

final class BackupServiceProvider
    extends $FunctionalProvider<BackupService, BackupService, BackupService>
    with $Provider<BackupService> {
  /// O serviço de backup: os arquivos temporários e as cópias de segurança ficam
  /// numa pasta própria, dentro dos dados do app.
  BackupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupServiceHash();

  @$internal
  @override
  $ProviderElement<BackupService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackupService create(Ref ref) {
    return backupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupService>(value),
    );
  }
}

String _$backupServiceHash() => r'a0d7f3ef97ac8fe9d05e1d45456893dab8094aa3';

/// Quando o usuário exportou o banco pela última vez (nulo = nunca).

@ProviderFor(lastBackup)
final lastBackupProvider = LastBackupProvider._();

/// Quando o usuário exportou o banco pela última vez (nulo = nunca).

final class LastBackupProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime?>, DateTime?, Stream<DateTime?>>
    with $FutureModifier<DateTime?>, $StreamProvider<DateTime?> {
  /// Quando o usuário exportou o banco pela última vez (nulo = nunca).
  LastBackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastBackupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastBackupHash();

  @$internal
  @override
  $StreamProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime?> create(Ref ref) {
    return lastBackup(ref);
  }
}

String _$lastBackupHash() => r'fc580e3f226086fb3ce916621f494c9b7281ad0b';

/// Tema, tamanho do texto e contraste escolhidos pelo usuário.

@ProviderFor(appearance)
final appearanceProvider = AppearanceProvider._();

/// Tema, tamanho do texto e contraste escolhidos pelo usuário.

final class AppearanceProvider
    extends
        $FunctionalProvider<
          AsyncValue<Appearance>,
          Appearance,
          Stream<Appearance>
        >
    with $FutureModifier<Appearance>, $StreamProvider<Appearance> {
  /// Tema, tamanho do texto e contraste escolhidos pelo usuário.
  AppearanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceHash();

  @$internal
  @override
  $StreamProviderElement<Appearance> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Appearance> create(Ref ref) {
    return appearance(ref);
  }
}

String _$appearanceHash() => r'9fb83fcb6e4c37410dd2630d37ec246f14b33d3b';
