# 0020 — Auditoria de UX: textos certos, erros em português e rede de acessibilidade

**Data:** 2026-09-21 · **Status:** ✅ concluído

## O que mudou

- **Texto da tela de IA corrigido.** Dizia "O IziFnc usa por padrão a Groq (principal) e a Anthropic
  (reserva)", o que é **falso** no app distribuído: não vai chave embutida, então sem configurar a
  importação não funciona. Agora diz logo de cara "Para importar uma planilha você precisa de uma chave de
  IA. A Groq tem plano grátis: crie a chave em console.groq.com/keys e cole em Principal." O restante
  (o que sai do aparelho, Reserva, Testar) ficou num trecho recolhido: "O que sai do aparelho?".
- **Erros da importação em português simples.** Em vez de "Não consegui ler essa aba: <exceção crua>",
  aparece o que aconteceu e o que fazer (chave recusada → conferir em Configurações › IA; modelo não
  encontrado → trocar o modelo; limite/sobrecarga → esperar um minuto; sem internet; arquivo que não é
  `.xlsx`). O texto técnico continua disponível, em letra pequena e selecionável, abaixo.
  Lógica pura em [`import_error_message.dart`](../lib/features/import/domain/import_error_message.dart).
- **"Fecha no dia (o "Até")" virou "Dia do fechamento da fatura"** (o "Até" é da planilha, não do usuário).
- **Rede de acessibilidade** na matriz de telas: alvo de toque de 48 dp e rótulo para leitor de tela em
  todas as telas (texto normal e grande, claro e escuro). Uma exceção conhecida e com autor:
  as linhas de saldo da home (28–34 dp), corrigidas na 0022; o teste **exige que o problema ainda exista**
  para a exceção sair da lista quando for corrigido.
- **Ferramenta de auditoria** versionada em [`tool/audit/`](../tool/audit/capturar_telas_test.dart):
  gera imagens de todas as telas com dados fictícios (não roda no CI).

## Por quê

O autor pediu para analisar se o app é prático de usar. A auditoria (14 telas capturadas, tarefas
percorridas, checagens automáticas; notas em `_local/claude/auditoria-ux.md`, não versionado) trouxe
uma lista de achados e ele escolheu quais aplicar. Esta entrega junta os que não mexem no desenho das telas.

- **Contraste fora do teste permanente:** o `textContrastGuideline` mede pixels da captura de teste e
  acusou 1,17:1 em texto escuro sobre fundo claro (falso positivo). Contraste se confere no aparelho.
- **O que está bom ficou como está:** valor primeiro com teclado, data de hoje, despesa como padrão,
  conta única pré-selecionada, folha de filtros e menu enxutos.

## Próximas entregas desta frente (escolhidas pelo autor)

- **0021** lançamento: tipo em grade fixa, "Salvar e novo", desfazer ao excluir.
- **0022** home: resumo claro, fatura aberta visível, lupa no lugar da busca fixa, valores maiores, linhas
  de saldo de 48 dp que filtram a lista, primeiros passos e aviso de backup. **O desenho é mostrado antes.**
- **0023** importar: checklist e aviso de IA no primeiro passo.
- Fora, por ora: chips de tipo com sinal de rolagem, botão "Lançar" no mês vazio, "Conta ou cartão" no
  lugar de "Onde", saldo por linha em Contas e cartões.

## Arquivos tocados

- `ai_settings_screen.dart`, `account_form_screen.dart`, `import_screen.dart`, `import_error_message.dart`.
- Testes: `import_error_message_test`, `settings_screen_test`, `card_closing_rule_test`, matriz
  `all_screens_test` (acessibilidade e `pumpScreen`).
- `tool/audit/capturar_telas_test.dart`.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. No app: ☰ › Configurações › Inteligência artificial mostra o texto novo; Contas › cartão novo mostra
   "Dia do fechamento da fatura"; importar com uma chave inválida mostra a mensagem em português.
3. Imagens da auditoria: `flutter test tool/audit/capturar_telas_test.dart`.
