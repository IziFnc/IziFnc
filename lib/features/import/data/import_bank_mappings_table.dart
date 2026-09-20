import 'package:drift/drift.dart';

import '../../accounts/data/accounts_table.dart';

/// Lembra, entre importações, para qual conta/cartão cada par (Banco, Tipo)
/// da planilha já foi mapeado — a pessoa importa uma aba por mês do histórico
/// (~10 vezes) e os nomes de banco não mudam de mês a mês.
///
/// [rawKey] é "banco normalizado|tipo", ex.: "bradesco|credito", "c6|debito".
/// Normalizado (minúsculo, sem acento) para "Bradesco" e "bradesco" caírem na
/// mesma chave — a planilha não é consistente na grafia.
class ImportBankMappings extends Table {
  TextColumn get rawKey => text().withLength(min: 1, max: 120)();

  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();

  @override
  Set<Column> get primaryKey => {rawKey};
}
