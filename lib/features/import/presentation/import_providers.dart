import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_slots_store.dart';
import '../data/configured_table_locator.dart';
import '../data/llm_slot.dart';
import '../data/llm_table_locator.dart';

/// Escolhe a planilha e devolve os bytes (nulo = a pessoa cancelou). Existe como
/// provider para os testes trocarem o seletor de arquivos do Android por um de
/// mentira; o padrão abre o seletor de verdade.
typedef PickWorkbook = Future<Uint8List?> Function();

final importFilePickerProvider = Provider<PickWorkbook>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    return file?.readAsBytes();
  },
);

/// Onde a configuração de IA do usuário (Principal e Reserva) fica guardada.
final aiSlotsStoreProvider = Provider<AiSlotsStore>((ref) => SecureAiSlotsStore());

/// Quem localiza as tabelas da planilha: a Principal e, se houver, a Reserva
/// que o usuário configurou (ver [ConfiguredTableLocator]).
///
/// O que o usuário configurou em Configurações › Inteligência artificial vale
/// mais que as chaves embutidas no build (`--dart-define`, usadas no
/// desenvolvimento): sem nada guardado, cai nelas.
final llmTableLocatorProvider = Provider<LlmTableLocator>(
  (ref) => ConfiguredTableLocator(
    resolveSlots: storedSlotsResolver(ref.watch(aiSlotsStoreProvider)),
    missingKeyMessage:
        'Nenhuma IA configurada. Abra o menu › Configurações › Inteligência '
        'artificial e configure a Principal — a chave grátis da Groq basta.',
  ),
);

/// Roda o teste de um slot (o botão "Testar"). Existe como provider para os
/// testes trocarem a chamada de rede por uma de mentira.
typedef PingRunner = Future<Duration> Function(LlmSlot slot);

final pingRunnerProvider = Provider<PingRunner>(
  (ref) =>
      (slot) => slot.buildLocator().ping(),
);
