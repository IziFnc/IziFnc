# 0048 — O olhinho dos saldos (1.0.4)

**Data:** 2026-11-17 · **Status:** ✅ concluído

## O que mudou

- **Saldos e totais começam escondidos** ("R$ ••••") toda vez que o app abre, como nos apps de banco; um **olhinho** mostra e esconde. Vale para o cartão da
  situação na home (Em conta, Faturas abertas, Entrou/Gastou), a tela Situação (saldos, em aberto, resumo do mês) e a lista de Contas e cartões.
- **Fica só na sessão**: nada é gravado no banco (sem migração, sem mexer no backup). A cada abertura volta a começar escondido (decisão do autor).
- **Não escondemos** o valor de cada lançamento, os campos de digitação nem a tela de pagar fatura (para pagar é preciso ver o valor).
- Leitor de tela: escondido, ouve "valor oculto" (e "Faturas abertas valor oculto"); o botão se chama "Mostrar valores" ou "Ocultar valores".
- Novo `MoneyText` central em [`money_text.dart`](../lib/core/widgets/money_text.dart); o guia ganhou uma frase sobre o olho.

## Por quê

Um amigo designer sugeriu esconder o saldo direto, como nos apps de banco (privacidade em lugar público e menos número de relance).

## Como verificar

`flutter test test/core/money_text_test.dart`. Os testes de tela que olham valores sobrescrevem `balancesHiddenAtStartProvider` com `false`. No emulador: abrir o app
(valores escondidos), tocar no olho (aparecem), ir à Situação e a Contas (mesmo estado).
