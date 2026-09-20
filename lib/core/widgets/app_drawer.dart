import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/entries/presentation/month_screen.dart';
import '../../features/import/presentation/import_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Os destinos do menu lateral, na ordem em que aparecem.
enum AppDestination {
  home('Início', Icons.home_outlined, Icons.home, MonthScreen.path),
  accounts(
    'Contas e cartões',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
    AccountsScreen.path,
  ),

  /// Um fluxo em passos, mas um destino do menu como os outros: tem o botão do
  /// menu (não uma seta de voltar, que levava de volta para a tela de onde se
  /// veio — ex.: Contas e cartões — e parecia um erro).
  importSheet('Importar planilha', Icons.upload_file_outlined, Icons.upload_file, ImportScreen.path),
  settings('Configurações', Icons.settings_outlined, Icons.settings, SettingsScreen.path);

  const AppDestination(this.label, this.icon, this.selectedIcon, this.path);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// Menu lateral. [current] é o destino da tela onde ele está, para marcá-lo.
///
/// Os destinos **trocam** a tela (`go`): voltar a partir deles sai do app, em
/// vez de empilhar uma tela sobre a outra a cada toque no menu.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.current});

  final AppDestination current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: current.index,
      onDestinationSelected: (index) {
        final destination = AppDestination.values[index];
        Navigator.of(context).pop(); // fecha o menu antes de navegar
        if (destination == current) return;
        context.go(destination.path);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 12),
          child: Row(
            children: [
              Image.asset(
                'assets/branding/logo.png',
                width: 48,
                height: 48,
                semanticLabel: 'Logo do IziFnc',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IziFnc', style: theme.textTheme.headlineSmall),
                    Text(
                      'Finanças, sem frescura',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final destination in AppDestination.values)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
