import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entry_filters.dart';

/// Os filtros da lista do mês. Vivem só na memória: não são gravados e voltam
/// ao normal ao trocar de mês (ver [reset]).
class EntryFiltersController extends Notifier<EntryFilters> {
  @override
  EntryFilters build() => const EntryFilters();

  void setKind(EntryKindFilter kind) => state = state.copyWith(kind: kind);
  void setQuery(String query) => state = state.copyWith(query: query);
  void setAccounts(Set<int> ids) => state = state.copyWith(accountIds: ids);
  void setSort(EntrySort sort) => state = state.copyWith(sort: sort);

  /// Tira os filtros que escondem lançamentos, mantendo a ordem escolhida.
  void clearFilters() => state = EntryFilters(sort: state.sort);

  /// Volta tudo ao padrão (usado ao trocar de mês).
  void reset() => state = const EntryFilters();
}

final entryFiltersProvider = NotifierProvider<EntryFiltersController, EntryFilters>(
  EntryFiltersController.new,
);
