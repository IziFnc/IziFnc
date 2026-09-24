import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import '../data/backup_service.dart';
import 'backup_actions.dart';
import 'settings_providers.dart';

/// Backup e restauração: o banco inteiro num arquivo `.sqlite`.
class DataSettingsScreen extends ConsumerStatefulWidget {
  const DataSettingsScreen({super.key});

  static const String path = '/configuracoes/dados';

  /// Depois deste tempo sem backup a tela avisa.
  static const staleAfter = Duration(days: 30);

  @override
  ConsumerState<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends ConsumerState<DataSettingsScreen> {
  bool _busy = false;

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final actions = ref.read(backupActionsProvider);
      final bytes = await actions.exportBytes();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Salvar backup',
        fileName: BackupService.fileNameFor(DateTime.now()),
        bytes: bytes,
      );
      if (saved == null) return; // cancelou
      await actions.markExported();
      if (mounted) _say('Backup salvo.');
    } catch (e) {
      if (mounted) _say('Não consegui salvar o backup: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final actions = ref.read(backupActionsProvider);
      final file = await FilePicker.pickFile(dialogTitle: 'Escolher backup');
      if (file == null) return; // cancelou
      final bytes = await file.readAsBytes();

      final check = await actions.inspect(bytes);
      if (check is BackupInvalid) {
        if (mounted) await _tell('Não dá para restaurar', check.reason);
        return;
      }
      if (!mounted) return;
      final ok = await _confirmRestore();
      if (ok != true) return;

      await actions.restore(bytes);
      if (!mounted) return;
      context.go('/');
      _say('Backup restaurado.');
    } catch (e) {
      if (mounted) await _tell('Não consegui restaurar', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restaurar este backup?'),
      content: const Text(
        'Isto SUBSTITUI todos os dados de agora (contas, lançamentos e '
        'configurações) pelos do arquivo.\n\n'
        'Por segurança, o IziFnc guarda antes uma cópia dos dados atuais neste aparelho.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restaurar')),
      ],
    ),
  );

  Future<void> _tell(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ok'))],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = ref.watch(lastBackupProvider).value;
    final stale = last == null || DateTime.now().difference(last) > DataSettingsScreen.staleAfter;

    return Scaffold(
      appBar: AppBar(title: const Text('Dados')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Seus dados ficam só neste aparelho. Se ele for perdido, trocado ou '
            'formatado, sem um backup eles somem. Salve uma cópia de tempos em tempos.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              stale ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: stale ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
            title: Text(last == null ? 'Último backup: nunca' : 'Último backup: ${Formatters.date(last)}'),
            subtitle: stale
                ? Text(last == null ? 'Você ainda não salvou nenhum backup.' : 'Já faz mais de 30 dias.')
                : null,
          ),
          const SizedBox(height: 8),
          TourTarget(
            anchor: TourAnchor.backupButton,
            child: FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.save_alt),
              label: const Text('Salvar backup'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar de um arquivo'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 24),
          Text(
            'O arquivo é uma cópia exata do banco (.sqlite) e tem todos os seus dados '
            'financeiros: guarde em um lugar seguro. As chaves de IA não vão nele.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
