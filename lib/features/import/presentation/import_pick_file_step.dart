import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import '../../accounts/presentation/account_form_screen.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../settings/presentation/ai_settings_screen.dart';
import '../../settings/presentation/ai_slots_controller.dart';
import 'import_checklist_rows.dart';

/// Passo 1: o que precisa estar pronto e o botão de escolher o arquivo.
class ImportPickFileStep extends ConsumerWidget {
  const ImportPickFileStep({
    super.key,
    required this.banner,
    required this.busy,
    required this.onPickFile,
  });

  final Widget banner;
  final bool busy;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasAccounts = ref.watch(accountsProvider).value?.isNotEmpty ?? false;
    final aiConfigured = ref.watch(aiConfiguredProvider);
    final hasAi = aiConfigured.value ?? false;
    final checking = !aiConfigured.hasValue; // ainda lendo o Keystore
    final ready = hasAccounts && hasAi;

    return Column(
      children: [
        banner,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.upload_file_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Importar a sua planilha',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha o arquivo .xlsx para importar uma aba (mês) por vez.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text('Antes de começar', style: theme.textTheme.titleSmall),
              ImportChecklistRow(
                done: hasAccounts,
                title: 'Contas e cartões cadastrados',
                hint: 'A planilha cita bancos e cartões: cadastre os que você usa.',
                actionLabel: 'Cadastrar',
                onAction: () => context.push(AccountFormScreen.newPath),
              ),
              ImportChecklistRow(
                done: hasAi,
                checking: checking,
                title: 'Chave de IA configurada',
                hint: 'A IA acha onde ficam as tabelas na aba. A Groq tem plano grátis.',
                actionLabel: 'Configurar',
                onAction: () => context.push(AiSettingsScreen.path),
              ),
              const ImportInfoRow(
                title: 'Ajuste o saldo inicial de cada conta',
                hint:
                    'Faça isso antes da primeira aba (em Contas e cartões); sem o '
                    'saldo inicial, o "em aberto" dos cartões pode ficar negativo.',
              ),
              const ImportInfoRow(
                title: 'A planilha precisa ter as tabelas certas',
                hint: '"Despesas Gerais" e "Entrada de Valor". Outro layout provavelmente não será lido.',
              ),
              const SizedBox(height: 16),
              // Sem `ready` aqui: diferente da v1 (dica avulsa), esta parada é
              // uma etapa **obrigatória** de uma sequência — se ficasse
              // esperando a chave de IA (algo que o tour não pede para
              // configurar), o passeio travaria para sempre neste passo.
              // Mostra mesmo com o botão desligado, como o passo do "Pagar
              // fatura": é educativo, não um apontador para o que já dá pra
              // usar agora.
              TourTarget(
                anchor: TourAnchor.importPickFile,
                child: FilledButton(
                  onPressed: busy || !ready ? null : onPickFile,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Escolher arquivo'),
                ),
              ),
              if (!ready && !checking)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Faça os itens pendentes acima para escolher o arquivo.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
