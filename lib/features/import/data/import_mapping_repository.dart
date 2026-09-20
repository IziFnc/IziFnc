import '../../../core/database/app_database.dart';
import '../domain/parsed_row.dart';

class ImportMappingRepository {
  ImportMappingRepository(this._db);

  final AppDatabase _db;

  /// Sugere uma conta/cartão para (banco, tipo): primeiro tenta achar uma
  /// conta já cadastrada com o mesmo nome (sem acento/caixa) e o tipo
  /// compatível (débito -> conta corrente, crédito -> cartão); se não achar,
  /// olha se esse par já foi mapeado numa importação anterior.
  Future<Account?> suggest(
    String banco,
    SourceTipo tipo,
    List<Account> accounts,
  ) async {
    final wantCard = tipo == SourceTipo.credito;
    final normalizedBanco = normalizeBankName(banco);
    for (final account in accounts) {
      if (account.kind.isCard != wantCard) continue;
      if (normalizeBankName(account.name) == normalizedBanco) return account;
    }

    final key = bankMappingKey(banco, tipo);
    final saved = await (_db.select(
      _db.importBankMappings,
    )..where((m) => m.rawKey.equals(key))).getSingleOrNull();
    if (saved == null) return null;
    for (final account in accounts) {
      if (account.id == saved.accountId) return account;
    }
    return null;
  }

  /// Lembra o mapeamento escolhido pelo usuário para a próxima importação.
  Future<void> remember(String banco, SourceTipo tipo, int accountId) {
    final key = bankMappingKey(banco, tipo);
    return _db
        .into(_db.importBankMappings)
        .insertOnConflictUpdate(
          ImportBankMappingsCompanion.insert(
            rawKey: key,
            accountId: accountId,
          ),
        );
  }
}
