import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';





/// Descrição, data e observação do lançamento. Vive fora de [EntryFormScreen] só
/// por tamanho; o estado fica lá.
class EntryDetailFields extends StatelessWidget {
  const EntryDetailFields({
    super.key,
    required this.description,
    required this.note,
    required this.date,
    required this.descriptionError,
    required this.onPickDate,
    required this.onDescriptionTyped,
  });

  final TextEditingController description;
  final TextEditingController note;
  final DateTime date;
  final String? descriptionError;
  final VoidCallback onPickDate;
  final VoidCallback onDescriptionTyped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: description,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: 'Descrição',
            errorText: descriptionError,
          ),
          onChanged: (_) => onDescriptionTyped(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.event_outlined),
          label: Text('Data: ${Formatters.date(date)}'),
          onPressed: onPickDate,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Observação (opcional)'),
        ),
      ],
    );
  }
}
