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

  @override
  Set<Column> get primaryKey => {id};
}
