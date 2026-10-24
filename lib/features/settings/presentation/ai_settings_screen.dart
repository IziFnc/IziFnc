import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import/data/ai_slots_store.dart';
import 'ai_slots_controller.dart';
import 'ai_intro_card.dart';
import 'ai_slot_card.dart';

/// Seção "Inteligência artificial" das Configurações: a **Principal** e a
/// **Reserva** que a importação de planilha usa, com a chave de cada um.
///
/// A Reserva só existe com uma Principal — a tela bloqueia o cartão dela, e a
/// regra de verdade fica em [AiSlotsStore].
class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  static const String path = '/configuracoes/ia';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(aiSlotsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inteligência artificial')),
      body: switch (slots) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AiIntroCard(),
            const SizedBox(height: 12),
            AiSlotCard(key: const ValueKey('slot-primary'), slot: AiSlot.primary, slots: value),
            const SizedBox(height: 12),
            AiSlotCard(key: const ValueKey('slot-backup'), slot: AiSlot.backup, slots: value),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('Erro ao carregar: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
