/// Tipo de conta.
///
/// Uma mesma instituição pode ter os dois (Bradesco conta + Bradesco cartão) ou
/// só um (Amazon é só cartão). Cada um vira uma conta separada no app — o nome
/// igual é o que liga os dois para quem lê.
///
/// Gravado como texto no banco (`textEnum`): **não renomear os valores** sem
/// migration, senão as linhas existentes deixam de ser lidas.
enum AccountKind {
  checking,
  creditCard;

  bool get isCard => this == creditCard;

  String get label => switch (this) {
    checking => 'Conta',
    creditCard => 'Cartão',
  };
}
