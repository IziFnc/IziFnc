import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/accounts/presentation/account_label.dart';

void main() {
  final created = DateTime(2025);
  Account card(String name, {int? owner}) => Account(
    id: 10,
    name: name,
    kind: AccountKind.creditCard,
    linkedAccountId: owner,
    closingDayInCurrent: false,
    createdAt: created,
  );
  final bradesco = Account(
    id: 1,
    name: 'Bradesco',
    kind: AccountKind.checking,
    closingDayInCurrent: false,
    createdAt: created,
  );

  group('cardTitle', () {
    test('prefixa "Cartão" no nome', () {
      expect(cardTitle(card('Amazon')), 'Cartão Amazon');
    });

    test('não repete quando o nome já começa com cartão', () {
      expect(cardTitle(card('Cartão Bradesco')), 'Cartão Bradesco');
      expect(cardTitle(card('cartao bradesco')), 'cartao bradesco');
    });
  });

  group('accountLabel', () {
    test('conta é só o nome', () {
      expect(accountLabel(bradesco), 'Bradesco');
    });

    test('cartão com a conta dona conhecida', () {
      expect(
        accountLabel(card('Amazon', owner: 1), all: [bradesco]),
        'Amazon · cartão do Bradesco',
      );
    });

    test('cartão sem dona (migrado) ou sem a lista', () {
      expect(accountLabel(card('Caixa'), all: [bradesco]), 'Caixa · cartão');
      expect(accountLabel(card('Amazon', owner: 1)), 'Amazon · cartão');
    });
  });
}
