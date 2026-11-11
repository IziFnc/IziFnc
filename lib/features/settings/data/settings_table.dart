// O drift le as expressoes de .check() na geracao de codigo; a auto-referencia
// do getter e o padrao documentado dele e nunca executa em runtime.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Configurações do app. Sempre uma única linha, `id = 1`, criada junto com o
/// banco.
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer().check(id.equals(1))();

  /// Dia em que o mês vira para débito e entradas (o dia do salário).
  /// 1 = mês do calendário. Cartões usam o próprio fechamento, não este.
  IntColumn get monthStartDay => integer()
      .withDefault(const Constant(1))
      .check(monthStartDay.isBetweenValues(1, 31))();

  /// Tema: 0 = segue o sistema, 1 = claro, 2 = escuro (ver `AppThemeMode`).
  /// Guardado como número, não como texto, para a migração ser só "adicionar
  /// coluna" — nada de recriar a tabela por causa de um CHECK.
  IntColumn get themeMode => integer().withDefault(const Constant(0))();

  /// Multiplicador do tamanho do texto, somado ao do sistema (1.0 = padrão).
  RealColumn get textScale => real().withDefault(const Constant(1.0))();

  /// Paleta com mais contraste (acessibilidade).
  BoolColumn get highContrast =>
      boolean().withDefault(const Constant(false))();

  /// Quando o usuário exportou o banco pela última vez (Configurações › Dados).
  /// Nulo = nunca. Adicionada no schema v7.
  DateTimeColumn get lastBackupAt => dateTime().nullable()();

  /// Em qual parada do tour guiado (feat 0026) a pessoa está — o índice do
  /// próximo `TourAnchor` a mostrar; `kTourSteps.length` = tour concluído (ou
  /// pulado). Adicionada no schema v8.
  IntColumn get tourStep => integer().withDefault(const Constant(0))();

  /// Quando a pessoa autorizou o envio do texto da planilha a um serviço de IA
  /// (feat 0038). Nulo = nunca autorizou. Adicionada no schema v9.
  DateTimeColumn get aiConsentAt => dateTime().nullable()();

  /// Versão do texto de privacidade que valeu na autorização. Texto novo
  /// (versão maior) pede a autorização de novo. 0 = nenhuma. Schema v9.
  IntColumn get aiConsentVersion => integer().withDefault(const Constant(0))();

  /// Para quem a pessoa autorizou, separado por `|` (`groq|anthropic|custom:host`).
  /// Trocar de serviço muda o destinatário, então pede de novo. Schema v9.
  TextColumn get aiConsentServices => text().withDefault(const Constant(''))();

  /// Versão do aviso de privacidade que a pessoa já viu na tela inicial.
  /// 0 = ainda não viu. Schema v9.
  IntColumn get privacyNoticeVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
