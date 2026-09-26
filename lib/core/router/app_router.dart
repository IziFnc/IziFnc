import 'package:go_router/go_router.dart';

import '../../features/accounts/domain/account_kind.dart';
import '../../features/accounts/presentation/account_form_screen.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/entries/presentation/entry_form_screen.dart';
import '../../features/entries/presentation/month_screen.dart';
import '../../features/import/presentation/import_screen.dart';
import '../../features/settings/presentation/ai_settings_screen.dart';
import '../../features/settings/presentation/data_settings_screen.dart';
import '../../features/settings/presentation/general_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../widgets/tour_target.dart';

/// Rotas do app.
///
/// Cada tela expõe as próprias constantes de caminho — assim o caminho mora
/// junto do widget que ele abre. As rotas fixas (`/contas/nova`) vêm antes
/// das com parâmetro (`/contas/:id`), porque o go_router casa na ordem.
GoRouter createAppRouter() => GoRouter(
  initialLocation: MonthScreen.path,
  // `tourRouteObserver` avisa um `TourTarget` quando a tela dele volta a
  // ficar visível (voltando de uma tela empilhada por cima) — ver o
  // doc-comment em tour_target.dart.
  observers: [tourRouteObserver],
  routes: [
    GoRoute(
      path: MonthScreen.path,
      builder: (context, state) => const MonthScreen(),
    ),
    GoRoute(
      path: EntryFormScreen.newPath,
      builder: (context, state) => const EntryFormScreen(),
    ),
    GoRoute(
      path: EntryFormScreen.editPattern,
      builder: (context, state) =>
          EntryFormScreen(entryId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: AccountsScreen.path,
      builder: (context, state) => const AccountsScreen(),
    ),
    GoRoute(
      path: AccountFormScreen.newPath,
      builder: (context, state) => AccountFormScreen(
        initialKind: (state.extra as AccountKind?) ?? AccountKind.checking,
      ),
    ),
    GoRoute(
      path: AccountFormScreen.editPattern,
      builder: (context, state) =>
          AccountFormScreen(accountId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: ImportScreen.path,
      builder: (context, state) => const ImportScreen(),
    ),
    GoRoute(
      path: SettingsScreen.path,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: GeneralSettingsScreen.path,
      builder: (context, state) => const GeneralSettingsScreen(),
    ),
    GoRoute(
      path: AiSettingsScreen.path,
      builder: (context, state) => const AiSettingsScreen(),
    ),
    GoRoute(
      path: DataSettingsScreen.path,
      builder: (context, state) => const DataSettingsScreen(),
    ),
  ],
);
