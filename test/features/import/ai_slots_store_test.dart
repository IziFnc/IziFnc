import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/data/llm_slot.dart';

const _groq = LlmSlot(kind: LlmServiceKind.groq, apiKey: 'gsk_principal_1234');
const _claude = LlmSlot(kind: LlmServiceKind.anthropic, apiKey: 'sk-ant-reserva-9876');
const _outro = LlmSlot(
  kind: LlmServiceKind.openaiCompatible,
  baseUrl: 'https://llm.exemplo.com/v1',
  model: 'meu-modelo',
);

void main() {
  group('regra: a Reserva nunca existe sem a Principal', () {
    test('gravar a Reserva sem Principal é recusado e nada é guardado', () async {
      final store = MemoryAiSlotsStore();

      await expectLater(store.write(AiSlot.backup, _claude), throwsStateError);
      expect(await store.read(AiSlot.backup), isNull);
    });

    test('com a Principal gravada, a Reserva pode ser gravada', () async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      await store.write(AiSlot.backup, _claude);

      expect((await store.read(AiSlot.primary))!.kind, LlmServiceKind.groq);
      expect((await store.read(AiSlot.backup))!.kind, LlmServiceKind.anthropic);
    });

    test('apagar a Principal apaga a Reserva junto', () async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      await store.write(AiSlot.backup, _claude);

      await store.delete(AiSlot.primary);

      expect(await store.read(AiSlot.primary), isNull);
      expect(await store.read(AiSlot.backup), isNull);
    });

    test('apagar só a Reserva deixa a Principal', () async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      await store.write(AiSlot.backup, _claude);

      await store.delete(AiSlot.backup);

      expect(await store.read(AiSlot.primary), isNotNull);
      expect(await store.read(AiSlot.backup), isNull);
    });

    test('trocar a Principal mantém a Reserva', () async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      await store.write(AiSlot.backup, _claude);

      await store.write(AiSlot.primary, _outro);

      expect((await store.read(AiSlot.primary))!.kind, LlmServiceKind.openaiCompatible);
      expect(await store.read(AiSlot.backup), isNotNull);
    });
  });

  group('só se grava o que dá para usar', () {
    test('Groq sem chave e "outro" sem modelo são recusados', () async {
      final store = MemoryAiSlotsStore();

      await expectLater(
        store.write(AiSlot.primary, const LlmSlot(kind: LlmServiceKind.groq, apiKey: '  ')),
        throwsArgumentError,
      );
      await expectLater(
        store.write(
          AiSlot.primary,
          const LlmSlot(kind: LlmServiceKind.openaiCompatible, baseUrl: 'https://x.io/v1'),
        ),
        throwsArgumentError,
      );
      expect(await store.read(AiSlot.primary), isNull);
    });
  });

  group('storedSlotsResolver', () {
    Future<List<LlmSlot>> fromBuild() async => const [
      LlmSlot(kind: LlmServiceKind.groq, apiKey: 'chave-do-build'),
    ];

    test('sem nada guardado, vale o que veio no build (dart-define)', () async {
      final resolve = storedSlotsResolver(MemoryAiSlotsStore(), fallback: fromBuild);

      expect((await resolve()).single.apiKey, 'chave-do-build');
    });

    test('Principal guardada vale mais que o build, e o build não entra de reserva', () async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _claude);
      final resolve = storedSlotsResolver(store, fallback: fromBuild);

      final slots = await resolve();
      expect(slots, hasLength(1));
      expect(slots.single.kind, LlmServiceKind.anthropic);
    });

    test('Principal e Reserva saem nessa ordem', () async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      await store.write(AiSlot.backup, _claude);
      final resolve = storedSlotsResolver(store, fallback: fromBuild);

      final slots = await resolve();
      expect(slots.map((s) => s.kind), [LlmServiceKind.groq, LlmServiceKind.anthropic]);
    });

    test('Reserva órfã (sobrou sem Principal) é ignorada mesmo assim', () async {
      final store = MemoryAiSlotsStore();
      store.seed(AiSlot.backup, _claude); // contorna a regra, como um dado antigo/corrompido
      final resolve = storedSlotsResolver(store, fallback: () async => const []);

      expect(await resolve(), isEmpty);
    });

    test('vale na hora: é lido a cada chamada', () async {
      final store = MemoryAiSlotsStore();
      final resolve = storedSlotsResolver(store, fallback: () async => const []);

      expect(await resolve(), isEmpty);
      await store.write(AiSlot.primary, _groq);
      expect(await resolve(), hasLength(1));
    });
  });

  group('SecureAiSlotsStore.decode (o que volta do armazenamento)', () {
    test('ida e volta preserva todos os campos', () {
      final json = SecureAiSlotsStore.encode(
        const LlmSlot(
          kind: LlmServiceKind.openaiCompatible,
          apiKey: 'k',
          model: 'm',
          baseUrl: 'https://x.io/v1',
        ),
      );
      final back = SecureAiSlotsStore.decode(json)!;

      expect(back.kind, LlmServiceKind.openaiCompatible);
      expect(back.apiKey, 'k');
      expect(back.model, 'm');
      expect(back.baseUrl, 'https://x.io/v1');
    });

    test('lixo, tipo desconhecido e vazio viram "não configurado", sem quebrar', () {
      expect(SecureAiSlotsStore.decode(null), isNull);
      expect(SecureAiSlotsStore.decode(''), isNull);
      expect(SecureAiSlotsStore.decode('não é json'), isNull);
      expect(SecureAiSlotsStore.decode('{"kind":"servico_que_nao_existe"}'), isNull);
      expect(SecureAiSlotsStore.decode('[1,2]'), isNull);
    });
  });

  group('maskKey', () {
    test('mostra só os 4 últimos caracteres', () {
      expect(maskKey('gsk_abcdefghij1234'), '••••1234');
    });

    test('chave curta não vaza nada', () {
      expect(maskKey('abc'), '••••');
      expect(maskKey('  abcd  '), '••••');
    });
  });

  group('validateBaseUrl', () {
    test('aceita https com host', () {
      expect(validateBaseUrl('https://api.openai.com/v1'), isNull);
      expect(validateBaseUrl('  https://llm.exemplo.com:8443/v1/  '), isNull);
    });

    test('recusa vazio, http e lixo', () {
      expect(validateBaseUrl(''), isNotNull);
      expect(validateBaseUrl('http://api.openai.com/v1'), contains('https'));
      expect(validateBaseUrl('api.openai.com/v1'), isNotNull);
      expect(validateBaseUrl('https://'), isNotNull);
    });
  });
}
