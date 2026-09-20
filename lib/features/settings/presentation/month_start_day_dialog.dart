import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories.dart';

/// Pergunta o novo dia de virada do mês e, se mudou, grava (os lançamentos de
/// conta corrente trocam de mês na mesma transação, ver o repositório).
Future<void> editMonthStartDay(
  BuildContext context,
  WidgetRef ref,
  int current,
) async {
  final day = await showDialog<int>(
    context: context,
    builder: (_) => _StartDayDialog(current: current),
  );
  if (day == null || day == current) return;
  await ref.read(settingsRepositoryProvider).setMonthStartDay(day);
}

class _StartDayDialog extends StatefulWidget {
  const _StartDayDialog({required this.current});

  final int current;

  @override
  State<_StartDayDialog> createState() => _StartDayDialogState();
}

class _StartDayDialogState extends State<_StartDayDialog> {
  late final _controller = TextEditingController(text: '${widget.current}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final day = int.tryParse(_controller.text);
    if (day == null || day < 1 || day > 31) {
      setState(() => _error = 'Um dia de 1 a 31');
      return;
    }
    Navigator.of(context).pop(day);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dia de virada do mês'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Débitos e entradas neste dia ou depois já contam para o mês '
            'seguinte. Use o dia em que o salário cai. 1 = mês normal.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Dia', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }
}
