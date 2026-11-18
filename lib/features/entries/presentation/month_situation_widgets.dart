import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/clock.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import '../../accounts/domain/account_kind.dart';
import '../../accounts/presentation/account_form_screen.dart';
import '../../accounts/presentation/account_label.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../import/presentation/import_screen.dart';
import '../../settings/presentation/data_settings_screen.dart';
import 'entry_form_screen.dart';
import 'month_providers.dart';


/// "Gastos no cartão Amazon" (sem repetir "cartão" quando o nome já diz).
String cardSpendLabel(Account card) {
  final title = cardTitle(card); // "Cartão Amazon" ou o próprio "Cartão Bradesco"
  return 'Gastos no ${title[0].toLowerCase()}${title.substring(1)}';
}

/// Para quem acabou de cadastrar a conta e ainda não lançou nada: o que fazer
/// agora, em vez de uma lista vazia. Some sozinho no primeiro lançamento.
class FirstStepsCard extends StatelessWidget {
  const FirstStepsCard({super.key, required this.hasCard});

  final bool hasCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Primeiros passos', style: theme.textTheme.titleMedium),
            ),
            step(
              Icons.tune,
              'Ajustar o saldo',
              'Diga quanto há hoje em cada conta.',
              () => context.go(AccountsScreen.path),
            ),
            if (!hasCard)
              TourTarget(
                anchor: TourAnchor.cardAdd,
                child: step(
                  Icons.credit_card,
                  'Cadastrar um cartão',
                  'Para lançar compras no crédito.',
                  () => context.push(
                    AccountFormScreen.newPath,
                    extra: AccountKind.creditCard,
                  ),
                ),
              ),
            step(
              Icons.upload_file_outlined,
              'Importar a sua planilha',
              'Se você já controla seus gastos numa planilha, traga um mês para cá.',
              () => context.go(ImportScreen.path),
            ),
            step(
              Icons.add,
              'Lançar o primeiro gasto',
              'Direto pelo botão +.',
              () => context.push(EntryFormScreen.newPath),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Faz tempo sem backup": uma linha, dispensável. Leva a Configurações › Dados.
class BackupNotice extends ConsumerWidget {
  const BackupNotice({super.key, required this.lastBackup});

  /// Nulo = nunca fez.
  final DateTime? lastBackup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final last = lastBackup;
    final text = last == null
        ? 'Você ainda não salvou um backup dos seus dados.'
        : 'Faz ${ref.read(clockProvider)().difference(last).inDays} dias que você não salva um backup.';
    final color = theme.colorScheme.onSecondaryContainer;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.backup_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color))),
          TextButton(
            onPressed: () => context.push(DataSettingsScreen.path),
            child: const Text('Salvar'),
          ),
          IconButton(
            tooltip: 'Dispensar',
            icon: Icon(Icons.close, color: color),
            onPressed: ref.read(backupNoticeDismissedProvider.notifier).dismiss,
          ),
        ],
      ),
    );
  }
}
