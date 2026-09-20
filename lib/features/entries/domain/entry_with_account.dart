import '../../../core/database/app_database.dart';

/// Um lançamento junto com a conta dele — o que as telas precisam para mostrar
/// "Mouse · Amazon · R$ 129,99" sem uma consulta por linha.
class EntryWithAccount {
  const EntryWithAccount(this.entry, this.account, {this.toAccount});

  final Entry entry;

  /// A conta do lançamento; em transferência, a origem.
  final Account account;

  /// Só em transferência: o destino.
  final Account? toAccount;
}
