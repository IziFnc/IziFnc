import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories.dart';
import '../domain/ai_consent.dart';

/// A autorização atual de envio do texto da planilha à IA (feat 0038).
final aiConsentProvider = StreamProvider<AiConsent>(
  (ref) => ref.watch(settingsRepositoryProvider).watchAiConsent(),
);

/// Versão do aviso de privacidade que a pessoa já viu na tela inicial.
final privacyNoticeVersionProvider = StreamProvider<int>(
  (ref) => ref.watch(settingsRepositoryProvider).watchPrivacyNoticeVersion(),
);
