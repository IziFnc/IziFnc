import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import/data/ai_slots_store.dart';
import '../../import/data/llm_slot.dart';
import '../../import/presentation/import_providers.dart';

/// O que está configurado hoje: a Principal e a Reserva (se houver).
class AiSlotsState {
  const AiSlotsState({this.primary, this.backup});

  final LlmSlot? primary;
  final LlmSlot? backup;

  LlmSlot? of(AiSlot slot) => slot == AiSlot.primary ? primary : backup;
}

/// Mantém a tela de IA em dia com o armazenamento. As regras (Reserva só com
/// Principal) moram em [AiSlotsStore]; aqui só se guarda, apaga e recarrega.
class AiSlotsController extends AsyncNotifier<AiSlotsState> {
  AiSlotsStore get _store => ref.read(aiSlotsStoreProvider);

  @override
  Future<AiSlotsState> build() => _load();

  Future<AiSlotsState> _load() async => AiSlotsState(
    primary: await _store.read(AiSlot.primary),
    backup: await _store.read(AiSlot.backup),
  );

  Future<void> save(AiSlot slot, LlmSlot value) async {
    await _store.write(slot, value);
    state = AsyncData(await _load());
  }

  /// Apagar a Principal apaga a Reserva junto (regra do armazenamento).
  Future<void> remove(AiSlot slot) async {
    await _store.delete(slot);
    state = AsyncData(await _load());
  }
}

final aiSlotsProvider = AsyncNotifierProvider<AiSlotsController, AiSlotsState>(
  AiSlotsController.new,
);

/// Há alguma IA que a importação consiga usar: a Principal guardada no app ou,
/// no desenvolvimento, as chaves do `--dart-define`. Atualiza quando a pessoa
/// salva ou remove uma chave na tela de IA.
final aiConfiguredProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(aiSlotsProvider); // recalcula quando a configuração muda
  final slots = await storedSlotsResolver(ref.read(aiSlotsStoreProvider))();
  return slots.isNotEmpty;
});
