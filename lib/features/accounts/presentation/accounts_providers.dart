import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories.dart';

part 'accounts_providers.g.dart';

@riverpod
Stream<List<Account>> accounts(Ref ref) =>
    ref.watch(accountsRepositoryProvider).watchAll();

/// Saldo de hoje de cada conta, em centavos com sinal (cartão fica negativo).
/// Chave: id da conta.
@riverpod
Stream<Map<int, int>> accountBalances(Ref ref) =>
    ref.watch(entriesRepositoryProvider).watchBalances();

/// Dia de virada do mês para débito e entradas.
@riverpod
Stream<int> monthStartDay(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchMonthStartDay();
