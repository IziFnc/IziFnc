import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import 'account_form_screen.dart';
import 'account_label.dart';
import 'accounts_providers.dart';

/// Lista de contas e cartões. (O dia de virada do mês mora em Configurações ›
/// Geral desde a feat 0016.)
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  static const String path = '/contas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contas e cartões')),
      drawer: const AppDrawer(current: AppDestination.accounts),
      floatingActionButton: TourTarget(
        anchor: TourAnchor.accountsAdd,
        child: FloatingActionButton(
          tooltip: 'Nova conta',
          onPressed: () => context.push(AccountFormScreen.newPath),
          child: const Icon(Icons.add),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          ...switch (accounts) {
            AsyncData(value: final list) when list.isEmpty => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhuma conta ainda. Toque em + para cadastrar.'),
              ),
            ],
            AsyncData(value: final list) => _grouped(list),
            AsyncError(:final error) => [Text('Erro: $error')],
            _ => [const Center(child: CircularProgressIndicator())],
          },
        ],
      ),
    );
  }

  /// Cada conta seguida dos seus cartões (recuados). Cartões sem conta dona —
  /// os que vieram de antes da feat 0006 — vão para o fim, com aviso.
  List<Widget> _grouped(List<Account> all) {
    final owners = [
      for (final a in all)
        if (!a.kind.isCard) a,
    ];
    final ownerIds = {for (final a in owners) a.id};
    final orphans = [
      for (final a in all)
        if (a.kind.isCard && !ownerIds.contains(a.linkedAccountId)) a,
    ];
    return [
      for (final owner in owners) ...[
        _AccountTile(account: owner),
        for (final card in all)
          if (card.kind.isCard && card.linkedAccountId == owner.id)
            _AccountTile(account: card, indented: true),
      ],
      for (final card in orphans) _AccountTile(account: card, orphan: true),
    ];
  }

}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    this.indented = false,
    this.orphan = false,
  });

  final Account account;

  /// Cartão listado abaixo da sua conta.
  final bool indented;

  /// Cartão sem conta dona (anterior à feat 0006): pede para vincular.
  final bool orphan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = account.kind.isCard
        ? [
            if (orphan)
              'sem conta vinculada — toque para vincular'
            else
              'cartão',
            'fecha dia ${account.closingDay}',
            if (account.dueDay != null) 'vence dia ${account.dueDay}',
          ]
        : ['Conta'];

    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: indented ? 48 : 16,
        end: 16,
      ),
      leading: Icon(
        orphan ? Icons.warning_amber_rounded : accountIcon(account),
        color: orphan ? colors.error : null,
      ),
      title: Text(account.name),
      subtitle: Text(
        details.join(' · '),
        style: orphan ? TextStyle(color: colors.error) : null,
      ),
      onTap: () => context.push(AccountFormScreen.editPath(account.id)),
    );
  }
}
