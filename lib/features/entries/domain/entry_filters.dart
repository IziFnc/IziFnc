import '../../../core/utils/search_key.dart';
import 'entry_type.dart';
import 'entry_with_account.dart';

/// Que tipo de lançamento a lista mostra.
enum EntryKindFilter {
  all('Tudo'),
  expense('Despesas'),
  income('Entradas'),
  transfer('Transferências'),
  billPayment('Faturas');

  const EntryKindFilter(this.label);
  final String label;

  /// `null` = qualquer tipo (inclusive os ajustes de saldo, que só aparecem em "Tudo").
  EntryType? get type => switch (this) {
    all => null,
    expense => EntryType.expense,
    income => EntryType.income,
    transfer => EntryType.transfer,
    billPayment => EntryType.billPayment,
  };
}

/// Como a lista é ordenada. O padrão (data) é a ordem em que o banco já entrega.
enum EntrySort {
  date('Data'),
  amountDesc('Valor');

  const EntrySort(this.label);
  final String label;
}

/// O que o usuário escolheu para enxergar da lista do mês.
///
/// Só muda **o que a lista mostra**: os totais do mês e os saldos continuam
/// sendo os de todos os lançamentos.
class EntryFilters {
  const EntryFilters({
    this.kind = EntryKindFilter.all,
    this.accountIds = const {},
    this.query = '',
    this.sort = EntrySort.date,
  });

  final EntryKindFilter kind;

  /// Vazio = todas as contas e cartões.
  final Set<int> accountIds;

  /// Texto buscado na descrição e na observação.
  final String query;
  final EntrySort sort;

  String get _trimmedQuery => query.trim();

  /// Algum filtro está escondendo lançamentos? Ordenar não esconde nada, então
  /// não conta.
  bool get isActive => activeCount > 0;

  /// Quantos filtros estão ligados (tipo, contas, busca) — o número do botão.
  int get activeCount =>
      (kind != EntryKindFilter.all ? 1 : 0) +
      (accountIds.isNotEmpty ? 1 : 0) +
      (_trimmedQuery.isNotEmpty ? 1 : 0);

  EntryFilters copyWith({
    EntryKindFilter? kind,
    Set<int>? accountIds,
    String? query,
    EntrySort? sort,
  }) => EntryFilters(
    kind: kind ?? this.kind,
    accountIds: accountIds ?? this.accountIds,
    query: query ?? this.query,
    sort: sort ?? this.sort,
  );
}

/// Aplica [filters] à lista do mês. Função pura.
///
/// - **Tipo:** "Tudo" inclui os ajustes de saldo; cada tipo mostra só o seu.
/// - **Conta ou cartão:** o lançamento entra se a conta dele **ou o destino** (em
///   transferência e pagamento de fatura) está entre as escolhidas — assim uma
///   transferência aparece nas duas pontas e o pagamento aparece na conta e no
///   cartão.
/// - **Busca:** texto contido na descrição ou na observação, sem diferenciar
///   maiúscula de minúscula nem acento (`searchKey`).
/// - **Ordem:** por valor é decrescente e **estável** (empate mantém a ordem de
///   entrada).
List<EntryWithAccount> applyFilters(
  List<EntryWithAccount> rows,
  EntryFilters filters,
) {
  final type = filters.kind.type;
  final query = searchKey(filters._trimmedQuery);

  bool matches(EntryWithAccount row) {
    final entry = row.entry;
    if (type != null && entry.type != type) return false;
    if (filters.accountIds.isNotEmpty &&
        !filters.accountIds.contains(entry.accountId) &&
        !(entry.toAccountId != null && filters.accountIds.contains(entry.toAccountId))) {
      return false;
    }
    if (query.isNotEmpty &&
        !searchKey(entry.description).contains(query) &&
        !searchKey(entry.note ?? '').contains(query)) {
      return false;
    }
    return true;
  }

  final result = [for (final row in rows) if (matches(row)) row];
  if (filters.sort == EntrySort.amountDesc) {
    // sort do Dart não é estável: o índice original desempata.
    final indexed = [for (var i = 0; i < result.length; i++) (i, result[i])];
    indexed.sort((a, b) {
      final byAmount = b.$2.entry.amountCents.compareTo(a.$2.entry.amountCents);
      return byAmount != 0 ? byAmount : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }
  return result;
}
