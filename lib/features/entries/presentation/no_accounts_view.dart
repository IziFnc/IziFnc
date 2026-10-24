import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import '../../accounts/presentation/account_form_screen.dart';

class NoAccountsView extends StatelessWidget {
  const NoAccountsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Cadastre sua primeira conta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Conta corrente ou cartão. Os lançamentos vão para ela.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TourTarget(
              anchor: TourAnchor.accountsAdd,
              child: FilledButton(
                onPressed: () => context.push(AccountFormScreen.newPath),
                child: const Text('Cadastrar conta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
