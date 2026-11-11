import 'package:flutter/material.dart';

import '../domain/privacy_text.dart';
import 'ai_consent_card.dart';

/// A política de privacidade, dentro do app (funciona offline). O texto vem de
/// `privacy_text.dart`, o mesmo que gera o PRIVACIDADE.md do repositório.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const String path = '/privacidade';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Política de privacidade', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Versão $kPrivacyVersion, em vigor desde $kPrivacyDate.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const AiConsentCard(),
          for (final section in kPrivacySections) ...[
            const SizedBox(height: 20),
            Text(section.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in section.paragraphs)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(p)),
            for (final item in section.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(right: 8), child: Text('•')),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
