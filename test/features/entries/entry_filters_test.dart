import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/domain/entry_filters.dart';
import 'package:izifnc/features/entries/domain/entry_type.dart';
import 'package:izifnc/features/entries/domain/entry_with_account.dart';

final _created = DateTime(2025);

Account _account(int id, String name, {AccountKind kind = AccountKind.checking}) => Account(
  id: id,
  name: name,
  kind: kind,
  closingDayInCurrent: false,
  createdAt: _created,
);

final _bradesco = _account(1, 'Bradesco');
final _c6 = _account(2, 'C6');
final _amazon = _account(3, 'Amazon', kind: AccountKind.creditCard);

var _nextId = 0;
EntryWithAccount _row(
  Account account,
  EntryType type,
  int cents, {
  String description = 'x',
  String? note,
  DateTime? date,
  Account? to,
}) => EntryWithAccount(
  Entry(
    id: _nextId++,
    accountId: account.id,
    toAccountId: to?.id,
    type: type,
    description: description,
    amountCents: cents,
    date: date ?? DateTime(2025, 12, 10),
    note: note,
    competence: 202512,
    createdAt: _created,
  ),
  account,
  toAccount: to,
);

void main() {
  final mercado = _row(_bradesco, EntryType.expense, 5000, description: 'Mercado', note: 'compra do mês');
  final salario = _row(_bradesco, EntryType.income, 500000, description: 'Salário');
  final mouse = _row(_amazon, EntryType.expense, 12999, description: 'Mouse');
  final transf = _row(_bradesco, EntryType.transfer, 20000, description: 'Transferência', to: _c6);
  final fatura = _row(_bradesco, EntryType.billPayment, 12999, description: 'Pagamento fatura Amazon', to: _amazon);
  final ajuste = _row(_c6, EntryType.adjustmentIncrease, 100, description: 'Ajuste de saldo');
  final all = [mercado, salario, mouse, transf, fatura, ajuste];

  List<String> names(List<EntryWithAccount> rows) => rows.map((r) => r.entry.description).toList();

  group('sem filtro', () {
    test('devolve tudo, na ordem recebida (o padrão é por data, como já vem do banco)', () {
      expect(names(applyFilters(all, const EntryFilters())), names(all));
    });

    test('não está ativo', () {
      expect(const EntryFilters().isActive, isFalse);
    });
  });

  group('por tipo', () {
    test('despesas', () {
      expect(names(applyFilters(all, const EntryFilters(kind: EntryKindFilter.expense))), ['Mercado', 'Mouse']);
    });

    test('entradas', () {
      expect(names(applyFilters(all, const EntryFilters(kind: EntryKindFilter.income))), ['Salário']);
    });

    test('transferências e faturas são grupos separados', () {
      expect(names(applyFilters(all, const EntryFilters(kind: EntryKindFilter.transfer))), ['Transferência']);
      expect(
        names(applyFilters(all, const EntryFilters(kind: EntryKindFilter.billPayment))),
        ['Pagamento fatura Amazon'],
      );
    });

    test('"Tudo" inclui os ajustes de saldo, e os outros tipos não', () {
      expect(names(applyFilters(all, const EntryFilters())), contains('Ajuste de saldo'));
      expect(names(applyFilters(all, const EntryFilters(kind: EntryKindFilter.expense))), isNot(contains('Ajuste de saldo')));
    });
  });

  group('por conta ou cartão', () {
    test('uma conta: os lançamentos dela', () {
      final rows = applyFilters(all, const EntryFilters(accountIds: {2}));
      expect(names(rows), ['Transferência', 'Ajuste de saldo'], reason: 'C6: destino da transferência e o ajuste');
    });

    test('transferência aparece nas duas pontas (origem e destino)', () {
      expect(names(applyFilters(all, const EntryFilters(accountIds: {1}))), contains('Transferência'));
      expect(names(applyFilters(all, const EntryFilters(accountIds: {2}))), contains('Transferência'));
    });

    test('pagamento de fatura aparece na conta e no cartão', () {
      expect(names(applyFilters(all, const EntryFilters(accountIds: {3}))), ['Mouse', 'Pagamento fatura Amazon']);
    });

    test('várias contas: soma dos lançamentos delas', () {
      final rows = applyFilters(all, const EntryFilters(accountIds: {2, 3}));
      expect(names(rows), unorderedEquals(['Mouse', 'Transferência', 'Pagamento fatura Amazon', 'Ajuste de saldo']));
    });
  });

  group('busca', () {
    test('acha na descrição, sem diferenciar maiúscula', () {
      expect(names(applyFilters(all, const EntryFilters(query: 'MERC'))), ['Mercado']);
    });

    test('não exige acento: "salario" acha "Salário" e "do mes" acha "do mês"', () {
      expect(names(applyFilters(all, const EntryFilters(query: 'salario'))), ['Salário']);
      expect(names(applyFilters(all, const EntryFilters(query: 'do mes'))), ['Mercado']);
    });

    test('e digitar o acento também acha o texto sem acento', () {
      final semAcento = _row(_bradesco, EntryType.expense, 100, description: 'Padaria Sao Joao');
      expect(names(applyFilters([semAcento], const EntryFilters(query: 'são joão'))), ['Padaria Sao Joao']);
    });

    test('acha na observação', () {
      expect(names(applyFilters(all, const EntryFilters(query: 'do mês'))), ['Mercado']);
    });

    test('espaços nas pontas não contam, e busca só de espaços é como sem busca', () {
      expect(names(applyFilters(all, const EntryFilters(query: '  mouse  '))), ['Mouse']);
      expect(const EntryFilters(query: '   ').isActive, isFalse);
      expect(applyFilters(all, const EntryFilters(query: '   ')), hasLength(all.length));
    });

    test('nada encontrado: lista vazia', () {
      expect(applyFilters(all, const EntryFilters(query: 'zzz')), isEmpty);
    });
  });

  group('combinados', () {
    test('tipo + conta + busca valem todos ao mesmo tempo', () {
      const f = EntryFilters(kind: EntryKindFilter.expense, accountIds: {1}, query: 'merc');
      expect(names(applyFilters(all, f)), ['Mercado']);
      expect(f.isActive, isTrue);
    });
  });

  group('ordenar', () {
    test('por valor, do maior para o menor', () {
      final rows = applyFilters(all, const EntryFilters(sort: EntrySort.amountDesc));
      expect(rows.map((r) => r.entry.amountCents), [500000, 20000, 12999, 12999, 5000, 100]);
    });

    test('empate de valor mantém a ordem original (estável)', () {
      final rows = applyFilters(all, const EntryFilters(sort: EntrySort.amountDesc));
      expect(names(rows).where((n) => n == 'Mouse' || n == 'Pagamento fatura Amazon'), ['Mouse', 'Pagamento fatura Amazon']);
    });

    test('ordenar sozinho não conta como "filtro ativo" (não esconde nada)', () {
      expect(const EntryFilters(sort: EntrySort.amountDesc).isActive, isFalse);
    });
  });

  group('copyWith e limpar', () {
    test('copyWith troca só o que foi pedido', () {
      const f = EntryFilters(kind: EntryKindFilter.income, query: 'a', accountIds: {1});
      final g = f.copyWith(kind: EntryKindFilter.expense);
      expect(g.kind, EntryKindFilter.expense);
      expect(g.query, 'a');
      expect(g.accountIds, {1});
    });

    test('quantos filtros estão ligados (para o número no botão)', () {
      expect(const EntryFilters().activeCount, 0);
      expect(const EntryFilters(kind: EntryKindFilter.income).activeCount, 1);
      expect(const EntryFilters(kind: EntryKindFilter.income, accountIds: {1, 2}, query: 'x').activeCount, 3);
    });
  });
}
