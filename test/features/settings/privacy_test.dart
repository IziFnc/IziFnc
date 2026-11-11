import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/settings/data/settings_repository.dart';
import 'package:izifnc/features/settings/domain/ai_consent.dart';
import 'package:izifnc/features/settings/domain/privacy_text.dart';

/// O texto de privacidade e a autorização de envio à IA (feat 0038).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('PRIVACIDADE.md', () {
    test('está em dia com o texto que o app mostra', () {
      final file = File('PRIVACIDADE.md').readAsStringSync().replaceAll('\r\n', '\n');
      expect(
        file,
        privacyMarkdown(),
        reason: 'rode `dart run tool/gerar_privacidade.dart` e commite o resultado',
      );
    });

    test('diz o que sai, o que não sai e como falar, sem prometer demais', () {
      final text = privacyMarkdown();
      expect(text, contains('todo o texto da aba'));
      expect(text, contains('Não saem: as células de número e de data'));
      expect(text, contains('fora do Brasil'));
      expect(text, contains(kPrivacyContactUrl));
      expect(text, contains('sem criptografia'), reason: 'o backup em texto puro é um risco declarado');
      expect(text, isNot(contains('nenhum dado sai')), reason: 'a importação com IA envia texto');
    });
  });

  group('AiConsent.covers', () {
    final at = DateTime(2026, 10, 25);

    test('nunca autorizou não cobre nada', () {
      expect(AiConsent.none.covers({'groq'}), isFalse);
    });

    test('cobre os serviços autorizados, e só eles', () {
      final c = AiConsent(at: at, version: kPrivacyVersion, services: {'groq'});
      expect(c.covers({'groq'}), isTrue);
      expect(c.covers({'groq', 'anthropic'}), isFalse, reason: 'a Reserva é outro destinatário');
      expect(c.covers({'custom:llm.exemplo.com'}), isFalse);
    });

    test('texto de privacidade mais novo que o aceito pede de novo', () {
      final old = AiConsent(at: at, version: kPrivacyVersion - 1, services: {'groq'});
      expect(old.covers({'groq'}), isFalse);
    });
  });

  group('SettingsRepository: autorização', () {
    late AppDatabase db;
    late SettingsRepository settings;

    setUp(() {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      settings = SettingsRepository(db, EntriesRepository(db));
    });
    tearDown(() => db.close());

    test('banco novo nasce sem autorização e sem ter visto o aviso', () async {
      final c = await settings.aiConsent();
      expect(c.granted, isFalse);
      expect(c.version, 0);
      expect(await settings.watchPrivacyNoticeVersion().first, 0);
    });

    test('conceder grava data, versão e serviços', () async {
      final at = DateTime(2026, 10, 25, 14, 30);
      await settings.grantAiConsent({'groq'}, at, version: kPrivacyVersion);

      final c = await settings.aiConsent();
      expect(c.granted, isTrue);
      expect(c.at, at);
      expect(c.version, kPrivacyVersion);
      expect(c.services, {'groq'});
    });

    test('conceder de novo na mesma versão acrescenta o serviço', () async {
      await settings.grantAiConsent({'groq'}, DateTime(2026, 10, 25), version: kPrivacyVersion);
      await settings.grantAiConsent({'anthropic'}, DateTime(2026, 10, 26), version: kPrivacyVersion);

      expect((await settings.aiConsent()).services, {'groq', 'anthropic'});
    });

    test('numa versão nova do texto, recomeça só com os serviços de agora', () async {
      await settings.grantAiConsent({'groq', 'anthropic'}, DateTime(2026, 10, 25), version: 1);
      await settings.grantAiConsent({'groq'}, DateTime(2026, 11, 2), version: 2);

      final c = await settings.aiConsent();
      expect(c.version, 2);
      expect(c.services, {'groq'});
    });

    test('revogar apaga data, versão e serviços', () async {
      await settings.grantAiConsent({'groq'}, DateTime(2026, 10, 25), version: kPrivacyVersion);
      await settings.revokeAiConsent();

      final c = await settings.aiConsent();
      expect(c.granted, isFalse);
      expect(c.at, isNull);
      expect(c.version, 0);
      expect(c.services, isEmpty);
    });

    test('marcar o aviso como visto guarda a versão do texto', () async {
      await settings.markPrivacyNoticeSeen(kPrivacyVersion);
      expect(await settings.watchPrivacyNoticeVersion().first, kPrivacyVersion);
    });
  });
}
