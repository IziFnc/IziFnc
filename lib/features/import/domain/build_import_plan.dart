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

String _two(int n) => n.toString().padLeft(2, '0');

/// Os avisos da prévia (feat 0025): o que a importação fez de diferente do que
/// está escrito na planilha, para nenhuma linha "sumir" sem explicação. A
/// planilha real mostrou que, sem isso, a pessoa conta as linhas e não bate.
List<String> importNotes(ParsedSheetData parsed, List<ImportPlanRow> plan) {
  final unchecked = plan.where((p) => !p.include).length;
  final undated = plan.where((p) => p.row.undated).length;
  final parcelas = plan.where((p) => p.row.originalDate != null).length;
  final semCartao = plan.where((p) => p.row.cardUnknown).length;
  return [
    if (unchecked > 0)
      '$unchecked vieram desmarcada(s) para você revisar (já importada antes, ou data muito longe do mês da aba).',
    if (parcelas > 0)
      '$parcelas parcela(s) estavam com a data da compra original e foram trazidas para o mês da aba (a data da compra fica na observação).',
    if (undated > 0) '$undated linha(s) estavam sem data na planilha e entram com a última data da aba.',
    if (semCartao > 0) '$semCartao fatura(s) sem o cartão na planilha usam o cartão escolhido no passo anterior.',
    if (parsed.mirrorsConsumed > 0)
      '${parsed.mirrorsConsumed} transferência(s) aparecem duas vezes na planilha (saída e entrada) e entram uma vez só.',
    'A tabela "Gastos Recorrentes" ainda não é importada.',
  ];
}

/// A observação do lançamento, com o que a importação fez com a data (feat 0025):
/// parcela trazida para o mês da aba guarda a data da compra; linha sem data avisa.
String? _noteFor(ParsedRow row, String? base) {
  final original = row.originalDate;
  final ate = row.lastInstallment;
  final compra = original == null ? null : 'compra em ${_two(original.day)}/${_two(original.month)}/${original.year}';
  final extra = compra != null && ate != null && base == null
      ? 'parcela até ${_two(ate.month)}/${ate.year} · $compra'
      : compra ?? (row.undated ? 'sem data na planilha' : null);
  if (extra == null) return base;
  return base == null ? extra : '$base · $extra';
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

    final (type, description, baseNote) = switch (row.kind) {
      ParsedKind.expense => (EntryType.expense, row.nome, row.observacao),
      ParsedKind.income => (EntryType.income, row.nome, row.observacao),
      ParsedKind.transfer => (EntryType.transfer, 'Transferência', null),
      // Sem o cartão na planilha, o nome técnico do mapeamento não vai para a
      // descrição; a lista do mês já mostra "Conta → fatura Cartão".
      ParsedKind.billPayment when row.cardUnknown => (EntryType.billPayment, 'Pagamento fatura', null),
      ParsedKind.billPayment => (EntryType.billPayment, 'Pagamento fatura ${row.destino}', null),
    };
    final note = _noteFor(row, baseNote);

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
