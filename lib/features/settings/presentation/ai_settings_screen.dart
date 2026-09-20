import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import/data/ai_slots_store.dart';
import '../../import/data/llm_slot.dart';
import '../../import/data/llm_table_locator.dart';
import '../../import/presentation/import_providers.dart';
import 'ai_slots_controller.dart';

/// Seção "Inteligência artificial" das Configurações: a **Principal** e a
/// **Reserva** que a importação de planilha usa, com a chave de cada um.
///
/// A Reserva só existe com uma Principal — a tela bloqueia o cartão dela, e a
/// regra de verdade fica em [AiSlotsStore].
class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  static const String path = '/configuracoes/ia';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(aiSlotsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inteligência artificial')),
      body: switch (slots) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _IntroCard(),
            const SizedBox(height: 12),
            _SlotCard(key: const ValueKey('slot-primary'), slot: AiSlot.primary, slots: value),
            const SizedBox(height: 12),
            _SlotCard(key: const ValueKey('slot-backup'), slot: AiSlot.backup, slots: value),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('Erro ao carregar: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSecondaryContainer;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    // O app não vem com chave nenhuma: sem configurar aqui, a
                    // importação não funciona. A frase diz isso logo de cara.
                    'Para importar uma planilha você precisa de uma chave de IA. '
                    'A Groq tem plano grátis: crie a chave em console.groq.com/keys '
                    'e cole em Principal.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            Theme(
              // Sem as linhas divisórias que o ExpansionTile põe por padrão.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  'O que sai do aparelho?',
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
                iconColor: color,
                collapsedIconColor: color,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A IA só serve para achar onde ficam as tabelas: vão apenas os '
                    'textos dos cabeçalhos. Valores e datas nunca saem do aparelho, e '
                    'as chaves ficam guardadas só nele.\n\n'
                    'A Reserva é opcional: só é chamada se a Principal falhar. O botão '
                    'Testar envia uma mensagem mínima e só roda quando você toca nele.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends ConsumerStatefulWidget {
  const _SlotCard({super.key, required this.slot, required this.slots});

  final AiSlot slot;
  final AiSlotsState slots;

  @override
  ConsumerState<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends ConsumerState<_SlotCard> {
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
