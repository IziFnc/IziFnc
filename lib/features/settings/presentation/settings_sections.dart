import 'package:flutter/material.dart';

import 'ai_settings_screen.dart';
import 'data_settings_screen.dart';
import 'general_settings_screen.dart';

/// Uma seção da tela de Configurações: um item da lista que abre a própria tela.
class SettingsSection {
  const SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
}

/// As seções, na ordem em que aparecem. Configuração nova entra aqui (e ganha
/// a própria tela e rota) em vez de inchar uma tela só.
const List<SettingsSection> settingsSections = [
  SettingsSection(
    icon: Icons.tune,
    title: 'Geral',
    subtitle: 'Tema, tamanho do texto e contraste',
    path: GeneralSettingsScreen.path,
  ),
  SettingsSection(
    icon: Icons.auto_awesome_outlined,
    title: 'Inteligência artificial',
    subtitle: 'Chave usada para importar planilhas',
    path: AiSettingsScreen.path,
  ),
  SettingsSection(
    icon: Icons.storage_outlined,
    title: 'Dados',
    subtitle: 'Backup e restauração',
    path: DataSettingsScreen.path,
  ),
];
