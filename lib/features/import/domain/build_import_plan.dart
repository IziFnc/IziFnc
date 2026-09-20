import '../../entries/data/entries_repository.dart';
import '../../entries/domain/entry_type.dart';
import 'import_plan.dart';
import 'parsed_row.dart';

/// Diz se já existe um lançamento igual a [draft] no banco.
typedef IsDuplicate = Future<bool> Function(EntryDraft draft);

/// O que a prévia mostra: as linhas prontas e o que ficou de fora com motivo.
class ImportPlan {
  const ImportPlan({
    required this.rows,
    required this.errors,
    this.leftOutByChoice = 0,
  });

  final List<ImportPlanRow> rows;
  final List<String> errors;

  /// Linhas que o usuário deixou de fora ao marcar um banco como "não importar".
  /// Não são erro: foi escolha, então só aparecem como número.
  final int leftOutByChoice;
}

/// O passo do mapeamento pode seguir?
///
/// Cada chave de [keys] (banco|tipo) precisa de uma decisão — ligada a uma conta
/// ([mapped]) ou marcada "não importar" ([skipped]) — e **pelo menos uma** tem de
/// ser importada: pular tudo não traria nada. Isto é o que permite importar só
/// uma parte da aba, em vez de exigir todos os bancos mapeados.
bool canContinueMapping({
  required Iterable<String> keys,
  required Map<String, int> mapped,
  required Set<String> skipped,
}) {
  final all = keys.toList();
  final decided = all.every((k) => mapped.containsKey(k) || skipped.contains(k));
  final importsSomething = all.any(mapped.containsKey);
  return decided && importsSomething;
}

/// Transforma o que foi lido da aba em lançamentos prontos para gravar.
///
/// [mapped] liga cada chave `banco|tipo` (ver [bankMappingKey]) ao id da conta
/// ou cartão escolhido no passo de mapeamento. Vem desmarcada por padrão a
/// linha que já existe no banco ([ImportSkipReason.duplicate]) ou que tem data
/// fora do padrão da aba ([ImportSkipReason.suspiciousDate]).
///
/// É uma função pura (só o [isDuplicate] toca em banco) — separada do widget
/// para poder ser testada sem UI.
Future<ImportPlan> buildImportPlan({
  required ParsedSheetData parsed,
  required Map<String, int> mapped,
  required IsDuplicate isDuplicate,
  Set<String> skipped = const {},
}) async {
  final rows = <ImportPlanRow>[];
  final errors = <String>[];
  var leftOutByChoice = 0;

  for (final row in parsed.all) {
    final destinoKey = row.destinoKey;

    // O usuário disse "não importar" para esse banco. Transferência e fatura
    // dependem dos dois lados: se qualquer um foi pulado, a linha inteira sai
    // (importar só a metade deixaria o saldo errado). Não é erro, é escolha.
    if (skipped.contains(row.mappingKey) ||
        (destinoKey != null && skipped.contains(destinoKey))) {
      leftOutByChoice++;
      continue;
    }

    final accountId = mapped[row.mappingKey];
    final toAccountId = destinoKey == null ? null : mapped[destinoKey];

    if (accountId == null || (destinoKey != null && toAccountId == null)) {
      errors.add('Linha ${row.sheetRow} ("${row.nome}"): conta ou cartão sem mapeamento — ignorada.');
      continue;
    }
    if (toAccountId != null && toAccountId == accountId) {
      errors.add(
        'Linha ${row.sheetRow} ("${row.nome}"): origem e destino foram '
        'mapeados para a mesma conta — ignorada.',
      );
      continue;
    }

    final (type, description, note) = switch (row.kind) {
      ParsedKind.expense => (EntryType.expense, row.nome, row.observacao),
      ParsedKind.income => (EntryType.income, row.nome, row.observacao),
      ParsedKind.transfer => (EntryType.transfer, 'Transferência', null),
      ParsedKind.billPayment => (EntryType.billPayment, 'Pagamento fatura ${row.destino}', null),
    };

    final draft = EntryDraft(
      accountId: accountId,
      toAccountId: toAccountId,
      type: type,
      description: description,
      amountCents: row.valorCents,
      date: row.data,
      note: note,
    );
    final reason = await isDuplicate(draft)
        ? ImportSkipReason.duplicate
        : row.suspiciousDate
        ? ImportSkipReason.suspiciousDate
        : null;

    rows.add(
      ImportPlanRow(
        row: row,
        accountId: accountId,
        toAccountId: toAccountId,
        type: type,
        description: description,
        note: note,
        include: reason == null,
        reason: reason,
      ),
    );
  }

  return ImportPlan(rows: rows, errors: errors, leftOutByChoice: leftOutByChoice);
}
