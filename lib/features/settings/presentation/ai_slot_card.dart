import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../import/data/ai_slots_store.dart';
import '../../import/data/llm_slot.dart';
import '../../import/data/llm_table_locator.dart';
import '../../import/presentation/import_providers.dart';
import 'ai_slots_controller.dart';

class AiSlotCard extends ConsumerStatefulWidget {
  const AiSlotCard({super.key, required this.slot, required this.slots});

  final AiSlot slot;
  final AiSlotsState slots;

  @override
  ConsumerState<AiSlotCard> createState() => AiSlotCardState();
}

class AiSlotCardState extends ConsumerState<AiSlotCard> {
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _url = TextEditingController();
  LlmServiceKind _kind = LlmServiceKind.groq;
  bool _editing = false;
  bool _touchedUrl = false; // só mostra o erro do endereço depois que o usuário mexe

  bool _testing = false;
  String? _testOk;
  String? _testError;

  LlmSlot? get _saved => widget.slots.of(widget.slot);
  bool get _isCustom => _kind == LlmServiceKind.openaiCompatible;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _url.dispose();
    super.dispose();
  }

  /// O que o formulário descreve agora. Campo de chave vazio mantém a chave já
  /// guardada — desde que o serviço seja o mesmo.
  LlmSlot _formSlot() {
    final typed = _key.text.trim();
    final saved = _saved;
    final reuse = saved != null && saved.kind == _kind && typed.isEmpty;
    final model = _model.text.trim();
    return LlmSlot(
      kind: _kind,
      apiKey: typed.isNotEmpty ? typed : (reuse ? saved.apiKey : null),
      model: model.isEmpty ? null : model,
      baseUrl: _isCustom ? _url.text.trim() : null,
    );
  }

  bool get _formValid {
    final slot = _formSlot();
    return slot.isUsable && (!_isCustom || validateBaseUrl(slot.baseUrl!) == null);
  }

  void _clearTest() {
    _testOk = null;
    _testError = null;
  }

  void _startEditing(LlmSlot saved) {
    setState(() {
      _editing = true;
      _kind = saved.kind;
      _model.text = saved.model ?? '';
      _url.text = saved.baseUrl ?? '';
      _key.clear();
      _touchedUrl = false;
      _clearTest();
    });
  }

  Future<void> _save() async {
    if (!_formValid) return;
    try {
      await ref.read(aiSlotsProvider.notifier).save(widget.slot, _formSlot());
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _editing = false;
      _key.clear();
      _clearTest();
    });
  }

  Future<void> _remove() async {
    final controller = ref.read(aiSlotsProvider.notifier);
    // Tirar a Principal leva a Reserva junto: pede confirmação se houver Reserva.
    if (widget.slot == AiSlot.primary && widget.slots.backup != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remover a Principal?'),
          content: const Text(
            'A Reserva também será removida, porque ela só existe junto com uma Principal.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover as duas'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await controller.remove(widget.slot);
    if (!mounted) return;
    setState(() {
      _editing = false;
      _clearTest();
    });
  }

  /// Só roda quando o usuário toca em Testar. Usa o que está no formulário
  /// (mesmo sem salvar) ou, se não há formulário aberto, o slot guardado.
  Future<void> _test(LlmSlot slot) async {
    setState(() {
      _testing = true;
      _clearTest();
    });
    String? ok;
    String? error;
    try {
      final took = await ref.read(pingRunnerProvider)(slot);
      ok = 'Funcionou · ${(took.inMilliseconds / 1000).toStringAsFixed(1).replaceAll('.', ',')} s';
    } on LlmLocatorException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Não consegui testar: $e';
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
      _testError = error;
    });
  }

  String _summary(LlmSlot saved) {
    final model = (saved.model == null || saved.model!.trim().isEmpty) ? 'modelo padrão' : saved.model!.trim();
    final key = (saved.apiKey == null || saved.apiKey!.trim().isEmpty)
        ? 'sem chave'
        : 'chave ${maskKey(saved.apiKey!)}';
    return '${saved.displayName} · $model · $key';
  }

  String get _helper => switch (_kind) {
    LlmServiceKind.groq => 'Plano grátis. Chave em console.groq.com/keys',
    LlmServiceKind.anthropic => 'Paga por uso. Chave em console.anthropic.com',
    LlmServiceKind.openaiCompatible =>
      'Qualquer serviço na API da OpenAI (OpenAI, OpenRouter, Together…). '
          'O modelo precisa aceitar saída em JSON.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = widget.slot == AiSlot.primary;

    // A Reserva não existe sem a Principal.
    if (!isPrimary && widget.slots.primary == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.slot.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Configure a Principal primeiro. A Reserva só faz sentido junto com ela.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final saved = _saved;
    final showForm = saved == null || _editing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.slot.label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              isPrimary
                  ? 'Usada primeiro.'
                  : 'Só é chamada se a Principal falhar, e a tela avisa quando isso '
                        'acontecer. Se for um serviço pago, pode gerar custo.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (showForm) ..._form(saved) else ..._summaryView(saved),
            if (_testing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_testOk != null) ...[
              const SizedBox(height: 12),
              Text(
                _testOk!,
                style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
              ),
            ],
            if (_testError != null) ...[
              const SizedBox(height: 12),
              Text(_testError!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _summaryView(LlmSlot saved) => [
    Text(_summary(saved), style: const TextStyle(fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(onPressed: _testing ? null : () => _test(saved), child: const Text('Testar')),
        TextButton(onPressed: () => _startEditing(saved), child: const Text('Editar')),
        TextButton(onPressed: _remove, child: const Text('Remover')),
      ],
    ),
  ];

  List<Widget> _form(LlmSlot? saved) {
    final valid = _formValid;
    return [
      DropdownButtonFormField<LlmServiceKind>(
        initialValue: _kind,
        isExpanded: true,
        decoration: InputDecoration(labelText: 'Serviço', helperText: _helper, helperMaxLines: 3),
        items: [
          for (final kind in LlmServiceKind.values) DropdownMenuItem(value: kind, child: Text(kind.label)),
        ],
        onChanged: (kind) => setState(() {
          if (kind != null) _kind = kind;
          _clearTest();
        }),
      ),
      const SizedBox(height: 8),
      if (_isCustom) ...[
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Endereço base',
            hintText: 'https://api.openai.com/v1',
            errorText: _touchedUrl ? validateBaseUrl(_url.text) : null,
          ),
          onChanged: (_) => setState(() {
            _touchedUrl = true;
            _clearTest();
          }),
        ),
        const SizedBox(height: 8),
      ],
      TextField(
        controller: _model,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: _isCustom ? 'Modelo' : 'Modelo (opcional)',
          hintText: _isCustom ? 'gpt-4o-mini' : 'deixe vazio para o padrão do serviço',
        ),
        onChanged: (_) => setState(_clearTest),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _key,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: _isCustom ? 'Chave (opcional)' : 'Chave',
          helperText: saved != null && saved.kind == _kind ? 'Deixe vazio para manter a chave atual' : null,
        ),
        onChanged: (_) => setState(_clearTest),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          FilledButton(onPressed: valid ? _save : null, child: const Text('Salvar')),
          OutlinedButton(
            onPressed: valid && !_testing ? () => _test(_formSlot()) : null,
            child: const Text('Testar'),
          ),
          if (saved != null)
            TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancelar')),
        ],
      ),
    ];
  }
}
