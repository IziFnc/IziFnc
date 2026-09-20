import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_drawer.dart';
import 'settings_sections.dart';

/// Configurações do app: uma lista de seções, cada uma numa tela própria.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String path = '/configuracoes';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      drawer: const AppDrawer(current: AppDestination.settings),
      body: ListView(
        children: [
          for (final section in settingsSections)
            ListTile(
              leading: Icon(section.icon),
              title: Text(section.title),
              subtitle: Text(section.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(section.path),
            ),
        ],
      ),
    );
  }
}
