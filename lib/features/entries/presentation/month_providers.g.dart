// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'month_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(monthEntries)
final monthEntriesProvider = MonthEntriesFamily._();

final class MonthEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EntryWithAccount>>,
          List<EntryWithAccount>,
          Stream<List<EntryWithAccount>>
        >
    with
        $FutureModifier<List<EntryWithAccount>>,
        $StreamProvider<List<EntryWithAccount>> {
  MonthEntriesProvider._({
    required MonthEntriesFamily super.from,
    required YearMonth super.argument,
  }) : super(
         retry: null,
         name: r'monthEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monthEntriesHash();

  @override
  String toString() {
    return r'monthEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<EntryWithAccount>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<EntryWithAccount>> create(Ref ref) {
    final argument = this.argument as YearMonth;
    return monthEntries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monthEntriesHash() => r'76ee12f91c3884f0fc13266796496f9389ab11a4';

final class MonthEntriesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<EntryWithAccount>>, YearMonth> {
  MonthEntriesFamily._()
    : super(
        retry: null,
        name: r'monthEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MonthEntriesProvider call(YearMonth month) =>
      MonthEntriesProvider._(argument: month, from: this);

  @override
  String toString() => r'monthEntriesProvider';
}

/// Total de lançamentos (todos os meses): zero = a pessoa ainda não começou.

@ProviderFor(entryCount)
final entryCountProvider = EntryCountProvider._();

/// Total de lançamentos (todos os meses): zero = a pessoa ainda não começou.

final class EntryCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Total de lançamentos (todos os meses): zero = a pessoa ainda não começou.
  EntryCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entryCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entryCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return entryCount(ref);
  }
}

String _$entryCountHash() => r'262247e7bc67075e921fb4e1645df75a04f6c7c0';

/// O aviso de backup da home foi dispensado (só nesta abertura do app: na
/// próxima, se o backup continuar vencido, ele volta).

@ProviderFor(BackupNoticeDismissed)
final backupNoticeDismissedProvider = BackupNoticeDismissedProvider._();

/// O aviso de backup da home foi dispensado (só nesta abertura do app: na
/// próxima, se o backup continuar vencido, ele volta).
final class BackupNoticeDismissedProvider
    extends $NotifierProvider<BackupNoticeDismissed, bool> {
  /// O aviso de backup da home foi dispensado (só nesta abertura do app: na
  /// próxima, se o backup continuar vencido, ele volta).
  BackupNoticeDismissedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupNoticeDismissedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupNoticeDismissedHash();

  @$internal
  @override
  BackupNoticeDismissed create() => BackupNoticeDismissed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$backupNoticeDismissedHash() =>
    r'142232ba5287cff018b9bc0213cc49a7389f578f';

/// O aviso de backup da home foi dispensado (só nesta abertura do app: na
/// próxima, se o backup continuar vencido, ele volta).

abstract class _$BackupNoticeDismissed extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Mês escolhido na tela do mês.
///
/// `null` = "o mês de hoje", que depende do dia de virada. A tela resolve isso,
/// porque o dia de virada vem de um Stream e só existe depois de carregar.

@ProviderFor(SelectedMonth)
final selectedMonthProvider = SelectedMonthProvider._();

/// Mês escolhido na tela do mês.
///
/// `null` = "o mês de hoje", que depende do dia de virada. A tela resolve isso,
/// porque o dia de virada vem de um Stream e só existe depois de carregar.
final class SelectedMonthProvider
    extends $NotifierProvider<SelectedMonth, YearMonth?> {
  /// Mês escolhido na tela do mês.
  ///
  /// `null` = "o mês de hoje", que depende do dia de virada. A tela resolve isso,
  /// porque o dia de virada vem de um Stream e só existe depois de carregar.
  SelectedMonthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedMonthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedMonthHash();

  @$internal
  @override
  SelectedMonth create() => SelectedMonth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(YearMonth? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<YearMonth?>(value),
    );
  }
}

String _$selectedMonthHash() => r'76257a76c2dadd40bea5b7bf4b1c4bcce32b362d';

/// Mês escolhido na tela do mês.
///
/// `null` = "o mês de hoje", que depende do dia de virada. A tela resolve isso,
/// porque o dia de virada vem de um Stream e só existe depois de carregar.

abstract class _$SelectedMonth extends $Notifier<YearMonth?> {
  YearMonth? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<YearMonth?, YearMonth?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<YearMonth?, YearMonth?>,
              YearMonth?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
