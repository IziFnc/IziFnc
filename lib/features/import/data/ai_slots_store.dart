import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'configured_table_locator.dart';
import 'llm_slot.dart';

/// Os dois lugares de IA que o usuário configura.
enum AiSlot {
  primary('Principal'),
  backup('Reserva');

  const AiSlot(this.label);
  final String label;
}

/// Onde a configuração de IA do usuário fica guardada, com as regras dela.
///
/// **A Reserva nunca existe sem a Principal**, e a regra mora aqui (e não só na
/// tela): gravar a Reserva sem Principal é recusado, e apagar a Principal apaga
/// a Reserva junto. Quem implementa só guarda e lê ([read], [persist], [erase]);
/// [write] e [delete] aplicam as regras e são o que o resto do app usa.
abstract class AiSlotsStore {
  Future<LlmSlot?> read(AiSlot slot);

  /// Guarda sem conferir nada. Não use direto: existe para as implementações.
  Future<void> persist(AiSlot slot, LlmSlot value);

  /// Apaga sem conferir nada. Não use direto: existe para as implementações.
  Future<void> erase(AiSlot slot);

  /// Grava o slot. Recusa o que não dá para usar ([ArgumentError]) e a Reserva
  /// sem Principal ([StateError]).
  Future<void> write(AiSlot slot, LlmSlot value) async {
    if (!value.isUsable) {
      throw ArgumentError.value(value, 'value', 'faltam chave, endereço ou modelo');
    }
    if (slot == AiSlot.backup && await read(AiSlot.primary) == null) {
      throw StateError('A Reserva só pode existir com uma Principal configurada.');
    }
    await persist(slot, value);
  }

  /// Apaga o slot. Apagar a Principal leva a Reserva junto.
  Future<void> delete(AiSlot slot) async {
    await erase(slot);
    if (slot == AiSlot.primary) await erase(AiSlot.backup);
  }
}

/// Guarda no armazenamento seguro do aparelho (Android Keystore) — não em
/// `SharedPreferences` nem no banco SQLite, que ficam em texto puro. Cada slot
/// é um JSON com tipo, chave, modelo e endereço.
///
/// A chave nunca é versionada, logada nem enviada a lugar nenhum além do
/// próprio serviço a que pertence.
class SecureAiSlotsStore extends AiSlotsStore {
  SecureAiSlotsStore([FlutterSecureStorage? storage])
    // `resetOnError` (padrão) descarta o dado em vez de travar quando o backup
    // automático do Android restaura o arquivo sem a chave do Keystore.
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _name(AiSlot slot) => 'izifnc.ai.${slot.name}';

  @override
  Future<LlmSlot?> read(AiSlot slot) async => decode(await _storage.read(key: _name(slot)));

  @override
  Future<void> persist(AiSlot slot, LlmSlot value) =>
      _storage.write(key: _name(slot), value: encode(value));

  @override
  Future<void> erase(AiSlot slot) => _storage.delete(key: _name(slot));

  static String encode(LlmSlot slot) => jsonEncode({
    'kind': slot.kind.name,
    if (slot.apiKey != null) 'apiKey': slot.apiKey!.trim(),
    if (slot.model != null) 'model': slot.model!.trim(),
    if (slot.baseUrl != null) 'baseUrl': slot.baseUrl!.trim(),
  });

  /// O que volta do armazenamento. Qualquer coisa estranha (vazio, JSON
  /// quebrado, tipo que não existe mais) vira "não configurado": melhor pedir
  /// a configuração de novo do que travar a tela.
  static LlmSlot? decode(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    try {
      final json = jsonDecode(stored);
      if (json is! Map) return null;
      final kind = LlmServiceKind.values.where((k) => k.name == json['kind']).firstOrNull;
      if (kind == null) return null;
      return LlmSlot(
        kind: kind,
        apiKey: json['apiKey'] as String?,
        model: json['model'] as String?,
        baseUrl: json['baseUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Para testes: nada de canal de plataforma.
class MemoryAiSlotsStore extends AiSlotsStore {
  final Map<AiSlot, LlmSlot> _slots = {};

  @override
  Future<LlmSlot?> read(AiSlot slot) async => _slots[slot];

  @override
  Future<void> persist(AiSlot slot, LlmSlot value) async => _slots[slot] = value;

  @override
  Future<void> erase(AiSlot slot) async => _slots.remove(slot);

  /// Coloca um slot **contornando as regras**, para simular dado antigo ou corrompido.
  void seed(AiSlot slot, LlmSlot value) => _slots[slot] = value;
}

/// Os slots que o usuário configurou; sem Principal guardada, vale o que veio
/// no build por `--dart-define` ([fallback]) — é assim que o desenvolvedor usa a
/// API direto. Lido a cada chamada, então salvar vale na hora.
///
/// A Reserva só entra se houver Principal, mesmo que o armazenamento esteja
/// inconsistente (segunda camada da regra; a primeira está em [AiSlotsStore]).
SlotsResolver storedSlotsResolver(AiSlotsStore store, {SlotsResolver fallback = envSlotsResolver}) {
  return () async {
    final primary = await store.read(AiSlot.primary);
    if (primary == null || !primary.isUsable) return fallback();
    final backup = await store.read(AiSlot.backup);
    return [primary, if (backup != null && backup.isUsable) backup];
  };
}

/// "••••abcd": só os 4 últimos caracteres, para reconhecer a chave sem expô-la.
String maskKey(String key) {
  final k = key.trim();
  return k.length <= 4 ? '••••' : '••••${k.substring(k.length - 4)}';
}

/// Erro de preenchimento do endereço base, ou `null` se está ok. Exige `https`:
/// a chave viaja no cabeçalho e não deve sair em texto puro pela rede.
String? validateBaseUrl(String value) {
  final text = value.trim();
  if (text.isEmpty) return 'Informe o endereço do serviço.';
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
    return 'Endereço inválido. Exemplo: https://api.openai.com/v1';
  }
  if (uri.scheme != 'https') return 'O endereço precisa começar com https://';
  return null;
}
