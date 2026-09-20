import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/import/data/fallback_table_locator.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/data/xlsx_workbook.dart';

final _grid = SheetGrid(const {}, 0);

const _found = TableLocations(
  despesasGerais: TableLocation(headerRow: 18, startCol: 1),
  entradaDeValor: TableLocation(headerRow: 18, startCol: 15),
);

/// Falha [failures] vezes com [error] e só então acerta.
class _FlakyLocator implements LlmTableLocator {
  _FlakyLocator(this.providerName, {required this.failures, required this.error});

  @override
  final String providerName;
  final int failures;
  final LlmLocatorException error;
  int calls = 0;

  @override
  Future<TableLocations> locate(SheetGrid grid, {required String sheetName}) async {
    calls++;
    if (calls <= failures) throw error;
    return _found;
  }
}

const _transient = LlmLocatorException('503', retryable: true);
const _permanent = LlmLocatorException('401 chave inválida');

void main() {
  group('RetryingTableLocator', () {
    test('tenta de novo em erro passageiro e acaba conseguindo', () async {
      final inner = _FlakyLocator('A', failures: 2, error: _transient);
      final locator = RetryingTableLocator(inner, retryDelay: Duration.zero);

      final result = await locator.locate(_grid, sheetName: 'x');
      expect(inner.calls, 3);
      expect(result.despesasGerais!.headerRow, 18);
    });

    test('não tenta de novo em erro permanente', () async {
      final inner = _FlakyLocator('A', failures: 5, error: _permanent);
      final locator = RetryingTableLocator(inner, retryDelay: Duration.zero);

      await expectLater(
        locator.locate(_grid, sheetName: 'x'),
        throwsA(isA<LlmLocatorException>()),
      );
      expect(inner.calls, 1, reason: 'repetir só atrasaria o erro de verdade');
    });

    test('desiste depois do limite de tentativas', () async {
      final inner = _FlakyLocator('A', failures: 99, error: _transient);
      final locator = RetryingTableLocator(inner, retryDelay: Duration.zero);

      await expectLater(
        locator.locate(_grid, sheetName: 'x'),
        throwsA(isA<LlmLocatorException>()),
      );
      expect(inner.calls, 3);
    });
  });

  group('FallbackTableLocator', () {
    test('o primeiro que responde vence, sem aviso', () async {
      final groq = _FlakyLocator('Groq', failures: 0, error: _permanent);
      final claude = _FlakyLocator('Anthropic', failures: 0, error: _permanent);

      final result = await FallbackTableLocator([groq, claude]).locate(_grid, sheetName: 'x');
      expect(result.servedBy, 'Groq');
      expect(result.fallbackNote, isNull);
      expect(claude.calls, 0, reason: 'a reserva é paga: só entra se preciso');
    });

    test('usa a reserva quando o principal falha, e avisa', () async {
      final groq = _FlakyLocator('Groq', failures: 9, error: _permanent);
      final claude = _FlakyLocator('Anthropic', failures: 0, error: _permanent);

      final result = await FallbackTableLocator([groq, claude]).locate(_grid, sheetName: 'x');
      expect(result.servedBy, 'Anthropic');
      expect(result.fallbackNote, allOf(contains('Anthropic'), contains('Groq'), contains('401')));
      expect(result.despesasGerais!.headerRow, 18);
    });

    test('se todos falham, a mensagem junta os erros de cada um', () async {
      final groq = _FlakyLocator('Groq', failures: 9, error: const LlmLocatorException('Groq 503'));
      final claude = _FlakyLocator('Anthropic', failures: 9, error: const LlmLocatorException('Anthropic 529'));

      await expectLater(
        FallbackTableLocator([groq, claude]).locate(_grid, sheetName: 'x'),
        throwsA(
          isA<LlmLocatorException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Groq 503'), contains('Anthropic 529')),
          ),
        ),
      );
    });

    test('retry por provedor vem antes da reserva', () async {
      // 503 passageiro na Groq: o retry resolve e a Anthropic paga nem é chamada.
      final groq = _FlakyLocator('Groq', failures: 1, error: _transient);
      final claude = _FlakyLocator('Anthropic', failures: 0, error: _permanent);
      final locator = FallbackTableLocator([
        RetryingTableLocator(groq, retryDelay: Duration.zero),
        RetryingTableLocator(claude, retryDelay: Duration.zero),
      ]);

      final result = await locator.locate(_grid, sheetName: 'x');
      expect(result.servedBy, 'Groq');
      expect(groq.calls, 2);
      expect(claude.calls, 0);
    });
  });
}
