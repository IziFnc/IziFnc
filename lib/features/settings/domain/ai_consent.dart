import 'privacy_text.dart';

/// A autorização que a pessoa deu para o envio do texto da planilha a serviços
/// de IA (feat 0038). Guardada só no aparelho, com data e versão do texto.
class AiConsent {
  const AiConsent({this.at, this.version = 0, this.services = const {}});

  /// Nunca autorizou.
  static const none = AiConsent();

  final DateTime? at;

  /// Versão de [kPrivacyVersion] que valia quando a pessoa aceitou.
  final int version;

  /// Chaves dos serviços autorizados (`groq`, `anthropic`, `custom:<host>`).
  final Set<String> services;

  bool get granted => at != null && services.isNotEmpty;

  /// Vale hoje para todos estes destinatários? Texto de privacidade mais novo
  /// que o aceito, ou um serviço que não estava na autorização, pede de novo.
  bool covers(Iterable<String> keys) {
    if (!granted || version < kPrivacyVersion) return false;
    return keys.every(services.contains);
  }

  /// A coluna `ai_consent_services` é um texto só, separado por `|`.
  static Set<String> parseServices(String raw) => {
    for (final part in raw.split('|'))
      if (part.trim().isNotEmpty) part.trim(),
  };

  static String joinServices(Set<String> keys) => (keys.toList()..sort()).join('|');
}
