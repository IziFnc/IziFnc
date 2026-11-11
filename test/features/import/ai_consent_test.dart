import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:izifnc/app.dart';
import 'package:izifnc/core/database/app_database.dart';
import 'package:izifnc/core/database/database_provider.dart';
import 'package:izifnc/core/utils/clock.dart';
import 'package:izifnc/core/widgets/tour_target.dart';
import 'package:izifnc/features/accounts/data/accounts_repository.dart';
import 'package:izifnc/features/accounts/domain/account_kind.dart';
import 'package:izifnc/features/entries/data/entries_repository.dart';
import 'package:izifnc/features/import/data/ai_slots_store.dart';
import 'package:izifnc/features/import/data/llm_slot.dart';
import 'package:izifnc/features/import/presentation/import_providers.dart';
import 'package:izifnc/features/settings/data/settings_repository.dart';
import 'package:izifnc/features/settings/domain/privacy_text.dart';
import 'package:izifnc/features/settings/presentation/privacy_notice.dart';

import '../../support/real_fonts.dart';

/// A autorização de envio do texto da planilha à IA (feat 0038): sem ela a
/// importação não começa; com ela, segue sem perguntar; trocar de destinatário
/// ou de versão do texto pergunta de novo; dá para revogar.
void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('pt_BR');
    await loadRealFonts();
  });

  late AppDatabase db;
  late SettingsRepository settings;
  late Uint8List bytes;
  var pickerCalls = 0;

  final fixedNow = DateTime(2026, 10, 25, 12);

  setUp(() async {
    pickerCalls = 0;
    bytes = File('docs/exemplo/espelho-do-real.xlsx').readAsBytesSync();
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    settings = SettingsRepository(db, EntriesRepository(db));
    await AccountsRepository(db, EntriesRepository(db)).create(name: 'Azul', kind: AccountKind.checking);
  });
  tearDown(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));

  Future<void> pumpApp(
    WidgetTester tester, {
    bool withBackup = false,
    bool tourOff = true,
    String path = '/importar',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ai = MemoryAiSlotsStore()
      ..seed(AiSlot.primary, const LlmSlot(kind: LlmServiceKind.groq, apiKey: 'gsk_teste_1234'));
    if (withBackup) {
      ai.seed(AiSlot.backup, const LlmSlot(kind: LlmServiceKind.anthropic, apiKey: 'sk-ant-teste-1234'));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          aiSlotsStoreProvider.overrideWithValue(ai),
          clockProvider.overrideWithValue(() => fixedNow),
          importFilePickerProvider.overrideWithValue(() async {
            pickerCalls++;
            return bytes;
          }),
          tourEnabledProvider.overrideWithValue(!tourOff),
        ],
        child: const IziFncApp(),
      ),
    );
    await tester.pumpAndSettle();
    // A home já é a rota inicial: não navega para ela de novo.
    if (path != '/') {
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
      await tester.pumpAndSettle();
    }
  }

  group('antes de escolher o arquivo', () {
    testWidgets('sem autorização, a folha aparece e o seletor de arquivo não abre', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Escolher arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('Antes de continuar'), findsOneWidget);
      expect(find.textContaining('Groq (Estados Unidos)'), findsOneWidget);
      expect(find.text(kConsentWhatStays), findsOneWidget, reason: 'diz o que NÃO vai');
      expect(pickerCalls, 0, reason: 'nada segue sem aceitar');
    });

    testWidgets('"Agora não" volta para a tela sem abrir o seletor nem gravar nada', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Escolher arquivo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      expect(find.text('Antes de continuar'), findsNothing);
      expect(find.text('Escolher arquivo'), findsOneWidget);
      expect(pickerCalls, 0);
      expect((await settings.aiConsent()).granted, isFalse);
    });

    testWidgets('aceitar grava data, versão e serviço, e segue para o seletor', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Escolher arquivo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aceitar e continuar'));
      await tester.pumpAndSettle();

      expect(pickerCalls, 1);
      expect(find.text('Mes1'), findsOneWidget, reason: 'abriu a planilha');
      final c = await settings.aiConsent();
      expect(c.at, fixedNow, reason: 'a data vem do relógio do app');
      expect(c.version, kPrivacyVersion);
      expect(c.services, {'groq'});
    });

    testWidgets('já autorizado: não pergunta de novo', (tester) async {
      await settings.grantAiConsent({'groq'}, fixedNow, version: kPrivacyVersion);
      await pumpApp(tester);

      await tester.tap(find.text('Escolher arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('Antes de continuar'), findsNothing);
      expect(pickerCalls, 1);
    });

    testWidgets('a Reserva é outro destinatário: autorizado só a Principal, pergunta de novo', (tester) async {
      await settings.grantAiConsent({'groq'}, fixedNow, version: kPrivacyVersion);
      await pumpApp(tester, withBackup: true);

      await tester.tap(find.text('Escolher arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('Antes de continuar'), findsOneWidget);
      expect(find.textContaining('Groq (Estados Unidos)'), findsOneWidget);
      expect(find.textContaining('Anthropic: apaga'), findsOneWidget);

      await tester.tap(find.text('Aceitar e continuar'));
      await tester.pumpAndSettle();
      expect((await settings.aiConsent()).services, {'groq', 'anthropic'});
    });

    testWidgets('texto de privacidade mais novo que o aceito pede de novo', (tester) async {
      await settings.grantAiConsent({'groq'}, fixedNow, version: kPrivacyVersion - 1);
      await pumpApp(tester);

      await tester.tap(find.text('Escolher arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('Antes de continuar'), findsOneWidget);
      expect(pickerCalls, 0);
    });
  });

  group('revogar', () {
    testWidgets('na tela de IA a autorização aparece e o botão a apaga', (tester) async {
      await settings.grantAiConsent({'groq'}, fixedNow, version: kPrivacyVersion);
      await pumpApp(tester, path: '/configuracoes/ia');

      // O cartão fica no fim da lista (abaixo da dobra): rola até ele.
      await tester.scrollUntilVisible(find.text('Revogar autorização'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Última autorização em 25/10/2026 para: Groq.'), findsOneWidget);

      await tester.tap(find.text('Revogar autorização'));
      await tester.pumpAndSettle();

      expect((await settings.aiConsent()).granted, isFalse);
      expect(find.textContaining('Ainda não autorizada'), findsOneWidget);
    });
  });

  group('tela de privacidade e aviso', () {
    testWidgets('a tela mostra a versão e as seções do texto', (tester) async {
      await pumpApp(tester, path: '/privacidade');

      expect(find.text('Política de privacidade'), findsOneWidget);
      expect(find.text('Versão $kPrivacyVersion, em vigor desde $kPrivacyDate.'), findsOneWidget);
      expect(find.text('Em resumo'), findsOneWidget);
    });

    testWidgets('o aviso da tela inicial aparece uma vez e some ao dispensar', (tester) async {
      await pumpApp(tester, path: '/');
      expect(find.text('Seus dados ficam neste aparelho, salvo o texto que você mandar à IA na importação.'), findsOneWidget);

      await tester.tap(
        find.descendant(of: find.byType(PrivacyNotice), matching: find.byTooltip('Dispensar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Seus dados ficam neste aparelho, salvo o texto que você mandar à IA na importação.'), findsNothing);
      // Leitura direta: um `.first` de stream do Drift não completa dentro do teste de widget.
      final row = await (db.select(db.appSettings)..limit(1)).getSingle();
      expect(row.privacyNoticeVersion, kPrivacyVersion);
    });

    testWidgets('já visto: o aviso não volta', (tester) async {
      await settings.markPrivacyNoticeSeen(kPrivacyVersion);
      await pumpApp(tester, path: '/');

      expect(find.text('Seus dados ficam neste aparelho, salvo o texto que você mandar à IA na importação.'), findsNothing);
    });
  });
}
