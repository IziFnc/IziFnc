import 'package:flutter_test/flutter_test.dart';
import 'package:ambrio/features/entries/domain/due_info.dart';

/// O próximo vencimento do cartão em palavras (feat 0042).
void main() {
  DueInfo at(int? dueDay, DateTime today) => DueInfo.of(dueDay: dueDay, today: today);

  test('sem dia de vencimento cadastrado', () {
    final info = at(null, DateTime(2026, 11, 10));
    expect(info.daysUntil, isNull);
    expect(info.label, 'sem vencimento cadastrado');
  });

  test('vence hoje, amanhã e daqui a N dias no mesmo mês', () {
    expect(at(10, DateTime(2026, 11, 10, 23, 59)).label, 'vence hoje');
    expect(at(11, DateTime(2026, 11, 10)).label, 'vence amanhã');
    final info = at(15, DateTime(2026, 11, 10));
    expect(info.daysUntil, 5);
    expect(info.label, 'vence em 5 dias');
  });

  test('já passou neste mês: o próximo é o do mês seguinte (sem dizer que venceu)', () {
    final info = at(5, DateTime(2026, 11, 10));
    expect(info.daysUntil, 25); // 5 de dezembro
    expect(info.label, 'vence em 25 dias');
  });

  test('virada de ano', () {
    expect(at(2, DateTime(2026, 12, 30)).daysUntil, 3); // 2 de janeiro
  });

  test('dia 31 em mês curto vence no último dia do mês', () {
    expect(at(31, DateTime(2026, 2, 20)).daysUntil, 8); // 28 de fevereiro
    expect(at(30, DateTime(2028, 2, 20)).daysUntil, 9); // 29 de fevereiro (bissexto)
  });
}
