import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
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
          for (final (i, section) in settingsSections.indexed)
            _sectionTile(context, section, highlight: i == 0),
        ],
      ),
    );
  }

  Widget _sectionTile(BuildContext context, SettingsSection section, {required bool highlight}) {
    final tile = ListTile(
      leading: Icon(section.icon),
      title: Text(section.title),
      subtitle: Text(section.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(section.path),
    );
    // Só a primeira seção é o alvo do tour (feat 0026): a lista inteira, sem
    // sobra de espaço acima nem abaixo, deixava a bolha sem onde caber.
    return highlight ? TourTarget(anchor: TourAnchor.settingsMenu, child: tile) : tile;
  }
}
