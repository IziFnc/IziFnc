import '../../entries/data/entries_repository.dart';
import '../../entries/domain/entry_type.dart';
import 'parsed_row.dart';

/// Por que a linha veio desmarcada por padrão na prévia.
enum ImportSkipReason { duplicate, suspiciousDate }

/// Uma linha já pronta para virar um `EntryDraft` — falta só o usuário
/// confirmar. As contas já foram resolvidas pelo mapeamento (passo 3 do
/// fluxo); `include` é editável na prévia (passo 4).
class ImportPlanRow {
  ImportPlanRow({
    required this.row,
    required this.accountId,
    this.toAccountId,
    required this.type,
    required this.description,
    this.note,
    required this.include,
    this.reason,
  });

  final ParsedRow row;

  /// A conta do lançamento. Em transferência e pagamento de fatura, a **origem**.
  final int accountId;

  /// Só em transferência (outra conta) e pagamento de fatura (o cartão).
  final int? toAccountId;

  final EntryType type;

  /// O que aparece na lista do mês. Em transferência e fatura segue o texto do
  /// formulário manual ("Transferência", "Pagamento fatura Amazon"), para o
  /// lançamento importado ser igual ao digitado — e a checagem de duplicata,
  /// determinística.
  final String description;
  final String? note;

  bool include;
  final ImportSkipReason? reason;

  EntryDraft toDraft() => EntryDraft(
    accountId: accountId,
    toAccountId: toAccountId,
    type: type,
    description: description,
    amountCents: row.valorCents,
    date: row.data,
    note: note,
  );
}
