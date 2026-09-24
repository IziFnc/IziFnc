import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/repositories.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../entries/presentation/month_screen.dart';
import '../domain/appearance.dart';
import 'month_start_day_dialog.dart';
import 'settings_providers.dart';

/// Aparência, acessibilidade, o dia de virada do mês e a versão do app. Cada
/// mudança vale na hora e fica gravada.
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  static const String path = '/configuracoes/geral';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider).value ?? const Appearance();
    final repo = ref.read(settingsRepositoryProvider);
    final theme = Theme.of(context);
    final size = TextSize.nearest(appearance.textScale);
    final startDay = ref.watch(monthStartDayProvider).value;
    final info = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Geral')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tema', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<AppThemeMode>(
            segments: [
              for (final mode in AppThemeMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {appearance.themeMode},
            onSelectionChanged: (s) => repo.setThemeMode(s.single),
          ),
          const SizedBox(height: 24),
          Text('Tamanho do texto', style: theme.textTheme.titleMedium),
          Text(
            'Soma-se ao tamanho que você já definiu no sistema.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Slider(
            value: TextSize.values.indexOf(size).toDouble(),
            min: 0,
            max: (TextSize.values.length - 1).toDouble(),
            divisions: TextSize.values.length - 1,
            label: size.label,
            onChanged: (v) => repo.setTextScale(TextSize.values[v.round()].scale),
          ),
          Text('${size.label} — o texto do app fica assim.'),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alto contraste'),
            subtitle: const Text('Cores mais fortes para facilitar a leitura.'),
            value: appearance.highContrast,
            onChanged: repo.setHighContrast,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text('Calendário', style: theme.textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.today_outlined),
            title: Text(
              startDay == null
                  ? 'O mês começa no dia …'
                  : 'O mês começa no dia $startDay',
            ),
            subtitle: const Text(
              'Para débito e entradas. Cartões usam o próprio fechamento.',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: startDay == null
                ? null
                : () => editMonthStartDay(context, ref, startDay),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Text('Sobre', style: theme.textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('IziFnc'),
            subtitle: Text(switch (info) {
              AsyncData(value: final i) => 'Versão ${i.version} (build ${i.buildNumber})',
              _ => 'Versão …',
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: const Text('Ver o tour de novo'),
            subtitle: const Text(
              'Refaz o passeio guiado pelas telas principais, do início.',
            ),
            onTap: () async {
              await repo.restartTour();
              if (context.mounted) context.go(MonthScreen.path);
            },
          ),
        ],
      ),
    );
  }
}
