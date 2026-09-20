import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/repositories.dart';
import '../../../core/utils/year_month.dart';
import '../domain/entry_with_account.dart';

part 'month_providers.g.dart';

@riverpod
Stream<List<EntryWithAccount>> monthEntries(Ref ref, YearMonth month) =>
    ref.watch(entriesRepositoryProvider).watchMonth(month);

/// Total de lançamentos (todos os meses): zero = a pessoa ainda não começou.
@riverpod
Stream<int> entryCount(Ref ref) => ref.watch(entriesRepositoryProvider).watchCount();

/// O aviso de backup da home foi dispensado (só nesta abertura do app: na
/// próxima, se o backup continuar vencido, ele volta).
@Riverpod(keepAlive: true)
class BackupNoticeDismissed extends _$BackupNoticeDismissed {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// Mês escolhido na tela do mês.
///
/// `null` = "o mês de hoje", que depende do dia de virada. A tela resolve isso,
/// porque o dia de virada vem de um Stream e só existe depois de carregar.
@Riverpod(keepAlive: true)
class SelectedMonth extends _$SelectedMonth {
  @override
  YearMonth? build() => null;

  void select(YearMonth month) => state = month;
}
