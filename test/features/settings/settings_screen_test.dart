import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/data/llm_slot.dart';
import 'package:izifnc/features/import/data/llm_table_locator.dart';
import 'package:izifnc/features/import/presentation/import_providers.dart';
import 'package:izifnc/features/settings/presentation/ai_settings_screen.dart';

const _groq = LlmSlot(kind: LlmServiceKind.groq, apiKey: 'gsk_principal_1234');
const _claude = LlmSlot(kind: LlmServiceKind.anthropic, apiKey: 'sk-ant-reserva-9876');

/// Sobe a tela com armazenamento em memória e um "Testar" de mentira, que
/// registra cada slot testado.
class _Harness {
  _Harness({MemoryAiSlotsStore? store, PingRunner? ping})
    : store = store ?? MemoryAiSlotsStore() {
    pingRunner =
        ping ??
        (slot) async {
          pinged.add(slot);
          return const Duration(milliseconds: 800);
        };
  }

  final MemoryAiSlotsStore store;
  late final PingRunner pingRunner;
  final pinged = <LlmSlot>[];

  Future<void> pump(WidgetTester tester) async {
    // A tela é comprida: com a janela padrão do teste o último cartão ficaria
    // fora da área visível.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiSlotsStoreProvider.overrideWithValue(store),
          pingRunnerProvider.overrideWithValue(pingRunner),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Finder _card(String slot) => find.byKey(ValueKey('slot-$slot'));
Finder _in(String slot, Finder matching) => find.descendant(of: _card(slot), matching: matching);
Finder _field(String slot, String label) => _in(slot, find.widgetWithText(TextField, label));
/// `byType` compara o tipo exato, então FilledButton/OutlinedButton/TextButton
/// não casam com ButtonStyleButton; o predicado aceita as subclasses.
Finder _button(String slot, String label) => _in(
  slot,
  find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  ),
);

Future<void> _pickKind(WidgetTester tester, String slot, LlmServiceKind kind) async {
  await tester.tap(_in(slot, find.byType(DropdownButtonFormField<LlmServiceKind>)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(kind.label).last);
  await tester.pumpAndSettle();
}

Future<void> _savePrimaryGroq(WidgetTester tester, {String key = 'gsk_principal_1234'}) async {
  await tester.enterText(_field('primary', 'Chave'), key);
  await tester.pump();
  await tester.tap(_button('primary', 'Salvar'));
  await tester.pumpAndSettle();
}

void main() {
  group('tela', () {
    testWidgets('mostra Principal e Reserva, sem nome de serviço no título, e diz que precisa de uma chave', (
      tester,
    ) async {
      await _Harness().pump(tester);

      expect(find.text('Principal'), findsOneWidget);
      expect(find.text('Reserva'), findsOneWidget);
      expect(find.text('Groq — principal'), findsNothing);
      expect(find.textContaining('você precisa de uma chave de IA'), findsOneWidget);
      expect(find.textContaining('console.groq.com/keys'), findsWidgets);
    });

    testWidgets('não afirma que o app já vem com uma IA "por padrão" (não vem chave embutida)', (tester) async {
      await _Harness().pump(tester);

      expect(find.textContaining('por padrão'), findsNothing);
    });

    testWidgets('o que sai do aparelho fica recolhido e abre com um toque', (tester) async {
      await _Harness().pump(tester);
      expect(find.textContaining('nunca saem do aparelho'), findsNothing);

      await tester.tap(find.text('O que sai do aparelho?'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Valores e datas nunca saem do aparelho'), findsOneWidget);
    });

    testWidgets('sem Principal, a Reserva fica bloqueada e sem campos', (tester) async {
      await _Harness().pump(tester);

      expect(_in('backup', find.textContaining('Configure a Principal primeiro')), findsOneWidget);
      expect(_in('backup', find.byType(TextField)), findsNothing);
    });

    testWidgets('não existe mais o cartão "Outro modelo" solto: ele virou uma escolha do seletor', (
      tester,
    ) async {
      await _Harness().pump(tester);

      expect(find.text('Outro modelo (compatível com OpenAI)'), findsNothing);
    });
  });

  group('Principal', () {
    testWidgets('Salvar fica desabilitado com a chave vazia', (tester) async {
      await _Harness().pump(tester);

      final save = tester.widget<FilledButton>(_button('primary', 'Salvar'));
      expect(save.onPressed, isNull);
    });

    testWidgets('salvar guarda, mostra só os 4 últimos da chave e libera a Reserva', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await _savePrimaryGroq(tester);

      final saved = await h.store.read(AiSlot.primary);
      expect(saved!.kind, LlmServiceKind.groq);
      expect(saved.apiKey, 'gsk_principal_1234');
      expect(_in('primary', find.textContaining('chave ••••1234')), findsOneWidget);
      expect(find.textContaining('principal_1234'), findsNothing, reason: 'a chave nunca aparece inteira');
      expect(_in('backup', find.textContaining('Configure a Principal primeiro')), findsNothing);
      expect(_field('backup', 'Chave'), findsOneWidget);
    });

    testWidgets('"Outro" pede endereço https e modelo, e só então deixa salvar', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await _pickKind(tester, 'primary', LlmServiceKind.openaiCompatible);

      FilledButton save() => tester.widget<FilledButton>(_button('primary', 'Salvar'));
      expect(_field('primary', 'Endereço base'), findsOneWidget);
      expect(_field('primary', 'Modelo'), findsOneWidget);
      expect(_field('primary', 'Chave (opcional)'), findsOneWidget);
      expect(save().onPressed, isNull);

      await tester.enterText(_field('primary', 'Endereço base'), 'http://inseguro.exemplo.com/v1');
      await tester.enterText(_field('primary', 'Modelo'), 'm');
      await tester.pump();
      expect(find.text('O endereço precisa começar com https://'), findsOneWidget);
      expect(save().onPressed, isNull);

      await tester.enterText(_field('primary', 'Endereço base'), 'https://llm.exemplo.com/v1');
      await tester.pump();
      expect(save().onPressed, isNotNull);

      await tester.tap(_button('primary', 'Salvar'));
      await tester.pumpAndSettle();
      final saved = await h.store.read(AiSlot.primary);
      expect(saved!.kind, LlmServiceKind.openaiCompatible);
      expect(saved.model, 'm');
      expect(saved.apiKey, isNull, reason: 'a chave é opcional nesse serviço');
      expect(_in('primary', find.textContaining('llm.exemplo.com · m · sem chave')), findsOneWidget);
    });

    testWidgets('Editar mostra o formulário; campo de chave vazio mantém a chave guardada', (
      tester,
    ) async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      final h = _Harness(store: store);
      await h.pump(tester);

      await tester.tap(_button('primary', 'Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('primary', 'Modelo (opcional)'), 'outro-modelo');
      await tester.pump();
      await tester.tap(_button('primary', 'Salvar'));
      await tester.pumpAndSettle();

      final saved = await store.read(AiSlot.primary);
      expect(saved!.model, 'outro-modelo');
      expect(saved.apiKey, 'gsk_principal_1234');
    });
  });

  group('Reserva', () {
    testWidgets('com Principal, a Reserva grava a chave dela', (tester) async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      final h = _Harness(store: store);
      await h.pump(tester);
      await _pickKind(tester, 'backup', LlmServiceKind.anthropic);

      await tester.enterText(_field('backup', 'Chave'), 'sk-ant-reserva-9876');
      await tester.pump();
      await tester.tap(_button('backup', 'Salvar'));
      await tester.pumpAndSettle();

      expect((await store.read(AiSlot.backup))!.kind, LlmServiceKind.anthropic);
      expect(_in('backup', find.textContaining('Anthropic')), findsWidgets);
    });

    testWidgets('remover só a Reserva não pede confirmação e mantém a Principal', (tester) async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      await store.write(AiSlot.backup, _claude);
      final h = _Harness(store: store);
      await h.pump(tester);

      await tester.tap(_button('backup', 'Remover'));
      await tester.pumpAndSettle();

      expect(await store.read(AiSlot.backup), isNull);
      expect(await store.read(AiSlot.primary), isNotNull);
    });
  });

  group('remover a Principal', () {
    Future<_Harness> withBoth(WidgetTester tester) async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      await store.write(AiSlot.backup, _claude);
      final h = _Harness(store: store);
      await h.pump(tester);
      return h;
    }

    testWidgets('com Reserva, avisa que ela sai junto e só apaga se confirmar', (tester) async {
      final h = await withBoth(tester);

      await tester.tap(_button('primary', 'Remover'));
      await tester.pumpAndSettle();
      expect(find.textContaining('A Reserva também será removida'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(await h.store.read(AiSlot.primary), isNotNull);
      expect(await h.store.read(AiSlot.backup), isNotNull);

      await tester.tap(_button('primary', 'Remover'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover as duas'));
      await tester.pumpAndSettle();
      expect(await h.store.read(AiSlot.primary), isNull);
      expect(await h.store.read(AiSlot.backup), isNull);
      expect(_in('backup', find.textContaining('Configure a Principal primeiro')), findsOneWidget);
    });

    testWidgets('sem Reserva, remove direto', (tester) async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      final h = _Harness(store: store);
      await h.pump(tester);

      await tester.tap(_button('primary', 'Remover'));
      await tester.pumpAndSettle();

      expect(await store.read(AiSlot.primary), isNull);
    });
  });

  group('botão Testar', () {
    testWidgets('nunca dispara sozinho: abrir a tela, digitar e salvar não testam nada', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);

      await _savePrimaryGroq(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(h.pinged, isEmpty);
    });

    testWidgets('fica desabilitado enquanto o formulário está incompleto', (tester) async {
      await _Harness().pump(tester);

      expect(tester.widget<OutlinedButton>(_button('primary', 'Testar')).onPressed, isNull);
    });

    testWidgets('testa o que está digitado, mesmo sem salvar, e mostra o resultado', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.enterText(_field('primary', 'Chave'), 'gsk_digitada_0001');
      await tester.pump();
      await tester.tap(_button('primary', 'Testar'));
      await tester.pumpAndSettle();

      expect(h.pinged, hasLength(1));
      expect(h.pinged.single.apiKey, 'gsk_digitada_0001');
      expect(await h.store.read(AiSlot.primary), isNull, reason: 'testar não salva');
      expect(_in('primary', find.text('Funcionou · 0,8 s')), findsOneWidget);
    });

    testWidgets('com slot já salvo, testa a configuração guardada', (tester) async {
      final store = MemoryAiSlotsStore();
      await store.write(AiSlot.primary, _groq);
      final h = _Harness(store: store);
      await h.pump(tester);

      await tester.tap(_button('primary', 'Testar'));
      await tester.pumpAndSettle();

      expect(h.pinged.single.apiKey, 'gsk_principal_1234');
      expect(_in('primary', find.textContaining('Funcionou')), findsOneWidget);
    });

    testWidgets('a falha aparece com a mensagem pronta do serviço', (tester) async {
      final h = _Harness(
        ping: (_) async => throw const LlmLocatorException('Groq recusou a chave. Confira se ela foi copiada inteira.'),
      );
      await h.pump(tester);

      await tester.enterText(_field('primary', 'Chave'), 'gsk_errada_0000');
      await tester.pump();
      await tester.tap(_button('primary', 'Testar'));
      await tester.pumpAndSettle();

      expect(_in('primary', find.textContaining('Groq recusou a chave')), findsOneWidget);
      expect(_in('primary', find.textContaining('Funcionou')), findsNothing);
    });

    testWidgets('mostra progresso enquanto o teste roda', (tester) async {
      final done = Completer<Duration>();
      final h = _Harness(ping: (_) => done.future);
      await h.pump(tester);

      await tester.enterText(_field('primary', 'Chave'), 'gsk_lenta_0002');
      await tester.pump();
      await tester.tap(_button('primary', 'Testar'));
      await tester.pump();

      expect(_in('primary', find.byType(LinearProgressIndicator)), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_button('primary', 'Testar')).onPressed, isNull);

      done.complete(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(_in('primary', find.byType(LinearProgressIndicator)), findsNothing);
      expect(_in('primary', find.text('Funcionou · 2,0 s')), findsOneWidget);
    });
  });
}
