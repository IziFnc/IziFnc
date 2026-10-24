import 'package:flutter/material.dart';

import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/tour_target.dart';
import '../domain/entry_type.dart';


/// Grade 2×2 fixa dos tipos de lançamento, não Wrap: num Wrap os chips mudavam
/// de linha conforme o tipo escolhido (a posição de cada um pulava). Quatro
/// tipos também não cabem lado a lado num celular de 360dp.
class EntryTypeGrid extends StatelessWidget {
  const EntryTypeGrid({
    super.key,
    required this.types,
    required this.selected,
    required this.tourReady,
    required this.accountIsCard,
    required this.checkingCount,
    required this.cardCount,
    required this.onSelected,
  });

  final List<EntryType> types;
  final EntryType selected;

  /// A parada do tour só vale ao criar.
  final bool tourReady;

  /// A conta escolhida é um cartão (cartão só aceita despesa nesta versão).
  final bool accountIsCard;
  final int checkingCount;
  final int cardCount;
  final void Function(EntryType type) onSelected;

  Widget _chip(EntryType type) => ChoiceChip(
    // O rótulo ocupa a largura toda para o texto ficar centrado.
    label: SizedBox(
      width: double.infinity,
      child: Text(type.label, textAlign: TextAlign.center),
    ),
    selected: selected == type,
    onSelected: switch (type) {
      EntryType.income when accountIsCard => null,
      // Precisa de duas contas.
      EntryType.transfer when checkingCount < 2 => null,
      // Precisa de um cartão e de uma conta para pagar.
      EntryType.billPayment when cardCount == 0 || checkingCount == 0 => null,
      _ => (_) => onSelected(type),
    },
  );

  @override
  Widget build(BuildContext context) {
    return TourTarget(
      anchor: TourAnchor.entryTypeGrid,
      ready: tourReady,
      child: Column(
        children: [
          for (var row = 0; row < types.length; row += 2) ...[
            if (row > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (final type in types.skip(row).take(2)) ...[
                  if (type != types[row]) const SizedBox(width: 8),
                  Expanded(child: _chip(type)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
