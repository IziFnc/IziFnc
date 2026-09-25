# Histórico de features

Cada entrega significativa do IziFnc vira um arquivo aqui. É a memória do projeto em
linguagem humana — o `git log` conta *o que* mudou, esta pasta conta **por que** mudou
e **como conferir** que funciona.

## Índice

| # | Entrega | Data | Status |
|---|---------|------|--------|
| [0001](0001-reestruturacao-base.md) | Reestruturação base: git, `_local/`, `feat/`, MCPs e esqueleto Riverpod + Drift | 2026-09-13 | ✅ concluído |
| [0002](0002-izifnc-e-mcps-validados.md) | Rename para IziFnc (`com.getulio.izifnc`) e MCPs validados de ponta a ponta | 2026-09-13 | ✅ concluído |
| [0003](0003-contas-e-lancamentos.md) | Contas, cartões e lançamentos, com a regra de mês por dia de corte | 2026-09-13 | ✅ concluído |
| [0004](0004-transferencias-e-saldos.md) | Transferências, pagamento de fatura, saldos na home e ajuste de saldo; primeira migração (v1→v2) | 2026-09-13 | ✅ concluído |
| [0005](0005-ajuste-ao-salvar.md) | Ajuste de saldo só é gravado ao salvar a conta (achado do teste no celular) | 2026-09-14 | ✅ concluído |
| [0006](0006-cartao-vinculado.md) | Cartão pertence a uma conta; "Pagar fatura" como tipo próprio; transferência só entre contas (migração v2→v3) | 2026-09-14 | ✅ concluído |
| [0007](0007-importar-planilha.md) | Importar planilha `.xlsx` (Despesas Gerais + Entrada de Valor + faturas e transferências, uma aba por vez; LLM localiza as tabelas, Groq principal e Anthropic de reserva; pipeline de validação; migração v3→v4) | 2026-09-19 | ✅ concluído |
| [0008](0008-configuracoes-geral.md) | Configurações em seções e aba Geral: tema, tamanho do texto e alto contraste (migração v4→v5) | 2026-09-19 | ✅ concluído |
| [0009](0009-ia-principal-reserva.md) | IA com Principal e Reserva (serviço à escolha: Groq, Anthropic ou compatível com OpenAI), regra "reserva nunca sem principal" e botão Testar sob demanda | 2026-09-19 | ✅ concluído |
| [0010](0010-menu-lateral.md) | Menu lateral (Início, Contas e cartões, Importar planilha, Configurações); ícones saem da barra da home | 2026-09-20 | ✅ concluído |
| [0011](0011-validacoes-dinheiro.md) | Validações no formulário: transferência bloqueia acima do saldo; fatura acima do em aberto | 2026-09-20 | ✅ concluído |
| [0012](0012-fechamento-por-cartao.md) | Regra do dia do fechamento por cartão: compra no dia entra na fatura atual ou na próxima (padrão "atual" no cartão novo; existentes ficam como estavam; migração v5→v6) | 2026-09-20 | ✅ concluído |
| [0013](0013-importacao-parcial.md) | Importar só uma parte da planilha: "Não importar" por banco no mapeamento e "marcar/desmarcar todas" por seção na prévia | 2026-09-20 | ✅ concluído |
| [0014](0014-fatura-conciliacao.md) | Pagar fatura com juros e encargos opcionais (fatura maior que o em aberto vira gasto no cartão) e aviso do que sobra quando se paga menos | 2026-09-20 | ✅ concluído |
| [0015](0015-home-filtros.md) | Home com filtros (busca, tipo, conta/cartão, ordem) e saldos recolhidos | 2026-09-20 | ✅ concluído |
| [0016](0016-ux-ui.md) | UX/UI: testes com fonte real e matriz de todas as telas (texto × tema), Sobre/versão e dia de virada em Geral, busca sem acento, passeio `integration_test` | 2026-09-21 | ✅ concluído |
| [0017](0017-identidade-visual.md) | Identidade visual: logo A (carteira verde) escolhida sobre a B (marinho, arquivada na tag `archive/0017-logo-b`); ícone adaptativo e logo no menu | 2026-09-21 | ✅ concluído |
| [0018](0018-dados-desempenho.md) | Dados e desempenho: backup e restauração do banco (`.sqlite`) em Configurações › Dados, índices de saldo (migração v6→v7), remoção de `fl_chart` e `web/`; APK arm64 mede 21,8 MB | 2026-09-21 | ✅ concluído |
| [0019](0019-rumo-1-0.md) | Rumo à 1.0: um app só (tela de IA e chave no Keystore na principal, id `com.getulio.izifnc`), assinatura de release com keystore próprio, README de usuário | 2026-09-21 | ✅ concluído |
| [0020](0020-textos-e-erros.md) | Auditoria de UX: texto da tela de IA corrigido (não usa IA "por padrão"), erros da importação em português, "Dia do fechamento da fatura", testes de acessibilidade (alvo de toque e rótulo) e ferramenta de capturas em `tool/audit/` | 2026-09-21 | ✅ concluído |
| [0021](0021-lancamento.md) | Lançamento: tipos em grade 2×2 fixa, "Salvar e novo" (com confirmação no rodapé) e excluir com Desfazer no lugar do diálogo | 2026-09-21 | ✅ concluído |
| [0022](0022-home-compacta.md) | Home compacta: topo de ~45% para ~20% da tela (mês e ações na barra, cartão de situação com folha de detalhes, tipo dentro dos filtros), valores maiores, guia de primeiros passos e aviso de backup | 2026-09-21 | ✅ concluído |
| [0023](0023-importar-checklist.md) | Importar: "Antes de começar" no primeiro passo (contas e chave de IA com atalho, lembretes de saldo inicial e de formato) e botão de escolher arquivo desligado enquanto faltar o essencial | 2026-09-21 | ✅ concluído |
| [0024](0024-versao-pessoal.md) | Duas versões do app: a do usuário (cola a própria chave) e a pessoal (chaves embutidas, id `.pessoal`, nunca publicada), gerada por `tool/build_pessoal.sh` | 2026-09-21 | ✅ concluído |
| [0025](0025-importacao-planilha-real.md) | Importação com a planilha real: linhas sem data e parcelas (inclusive formato antigo) no mês da aba, fatura sem cartão perguntada no mapeamento, segunda tentativa da IA, avisos na prévia; diagnóstico `tool/diagnosticar_planilha.dart` e modelo fictício `armadilhas-do-real` | 2026-09-22 | ✅ concluído |
| [0026](0026-guia-no-app.md) | Guia dentro do app: tour guiado de 7 paradas na primeira vez, andando sozinho de tela em tela, com "Pular o tour" e "Ver o tour de novo"; corrigidos 4 bugs visuais achados no celular real (rc.6) | 2026-09-23/24 | ✅ concluído |

## Backlog

Próximas entregas, **em ordem**. Cada uma pequena e fechada antes da seguinte.

| # | Entrega | Por que nesta posição |
|---|---------|------|
| — | ✅ **`v1.0.0-rc.6`** publicado no GitHub Releases (APK arm64 assinado, pré-lançamento, 2026-09-24; corrige 4 bugs visuais do tour da 0026, achados testando o rc.5 no celular do autor). Falta o **ciclo de testadores** e então a **1.0.0**. | Depois: aposentar a `release/teste-usuarios` (já arquivada na tag `archive/release-teste`). |
| 0027 | Pagar fatura em % de juros (hoje só aceita a diferença em R$) | Achado testando a 0025 no emulador: a fatura do banco vem em taxa (ex.: "2,5% a.m."), não em reais; quem paga tem que fazer a conta de cabeça. Pequeno. |
| 0028 | Atalho direto para "Pagar fatura" a partir do próprio cartão (folha de situação) | Mesmo teste: hoje tocar no cartão só filtra a lista; "Pagar fatura" está escondido na grade do "+" junto com Despesa/Entrada/Transferência. |
| 0029 | Importar todas as abas de uma vez | Hoje é uma aba por vez; ajuda quem tem o ano inteiro na mesma planilha. (1.1+) |
| 0030 | Exportar relatório do mês | Para o agente externo de análise que o autor já usa. (1.1+) |
| 0031 | Parcelamento de compras e de fatura | Na planilha, as parcelas são linhas repetidas mês a mês; parcelas futuras servem aos dois. (1.1+) |
| 0032 | Recorrentes (inclui importar a tabela "Gastos Recorrentes") | Mesma lógica: dá para importar como lançamentos simples antes. (1.1+) |

**Futuras, sem ordem:** poupança (junto com rendimento de investimentos, talvez um app
à parte) · fatura parcial com saldo rolando para o mês seguinte · extrato bancário (um
adaptador por banco, porque cada um exporta diferente) · agente embutido ·
estorno/cashback em cartão · plano "serviço IziFnc" com limite (1 importação de planilha e
5 relatórios de extrato por mês) como alternativa a colocar a própria chave.

**Pontos encontrados em uso** (anotados em 2026-09-19):

- ✅ **Pagar fatura acima do valor em aberto** — resolvido na [0011](0011-validacoes-dinheiro.md)
  (bloqueia; pagar menos é permitido).
- ✅ **Transferir mais do que há na conta** — resolvido na 0011 (bloqueia: "conta não transfere o
  que não tem"; cheque especial ficou de fora).

> **Reaberto e resolvido na [0012](0012-fechamento-por-cartao.md):** "compra no cartão no dia
> do fechamento". Tinha sido descartado como "não é bug" (o app seguia a regra da planilha do autor:
> no dia do fechamento vai para o mês seguinte). A pesquisa mostrou que os bancos **divergem**
> (Itaú e Mercado Pago: fatura atual; Nubank: próxima), então virou uma escolha por cartão.

> **Regra que a 0011 seguiu:** a validação de saldo/fatura fica no
> **formulário manual**, não no `EntriesRepository.save`. A importação grava o histórico
> sem os saldos iniciais (as faturas da aba mais antiga pagam compras de meses que ainda não
> estão no banco), e uma validação no repositório rejeitaria linhas legítimas.

## Como adicionar uma entrada

1. Copie [`TEMPLATE.md`](TEMPLATE.md) para `NNNN-nome-curto.md`, com `NNNN` sendo o
   próximo número da sequência (`0002`, `0003`, …) e o nome em kebab-case sem acento.
2. Preencha as seções. A mais importante é **Por quê** — daqui a seis meses, é a única
   que não dá para reconstruir olhando o código.
3. Adicione a linha correspondente na tabela do índice acima.

## Convenções

- **Um arquivo por entrega**, não por commit. Se uma feature levou oito commits, ela
  ainda é uma entrada só.
- **Numeração nunca é reaproveitada.** Se uma entrega for revertida, o arquivo continua
  aqui com status `❌ revertido` e uma nota explicando o motivo.
- **Status possíveis:** `✅ concluído` · `🚧 em andamento` · `❌ revertido`
- Rascunho e raciocínio em andamento **não** vêm para cá — isso é `_local/`, que não é
  versionado. Aqui entra só o que já está fechado.
