# 0009 — IA com Principal e Reserva, e botão Testar

**Data:** 2026-09-19 · **Status:** ✅ concluído

## O que mudou

**Em todas as versões (base):**

- A cadeia de IA da importação passou a ser uma **lista ordenada de slots**: o primeiro é a
  **Principal**, os seguintes ficam de **Reserva**. Cada slot é um `LlmSlot` (serviço, chave,
  modelo opcional, endereço no caso de "outro"). Serviços possíveis: **Groq**, **Anthropic** e
  **Outro, compatível com OpenAI**.
- `ConfiguredTableLocator` recebe um `resolveSlots` no lugar de `resolveKey` +
  `resolveCustom`. O build padrão (`main` e `feat/…`) continua usando as chaves de
  `--dart-define` (Groq principal, Anthropic reserva), **sem tela de configuração**.
- Todo localizador ganhou `ping()` (`PingableLocator`): uma requisição mínima ("Responda
  apenas: ok", 16 tokens, **nenhum dado da planilha**) que devolve o tempo de resposta ou um
  erro já traduzido — 401/403 "recusou a chave", 404 "não achou o modelo ou o endereço",
  429 "limite de uso", 5xx "fora do ar", rede "sem conexão".
- Groq e Anthropic aceitam **modelo** escolhido (o padrão continua `--dart-define`-ável).

**Só na versão dos testadores (`release/teste-usuarios`):**

- A tela **Configurações › Inteligência artificial** ficou enxuta: um aviso curto (o que sai do
  aparelho e o que o IziFnc usa por padrão), depois só **Principal** e **Reserva**, sem nome de
  provedor no título. Cada uma tem um seletor de serviço; o cartão avulso "Outro modelo" saiu,
  virou uma das opções do seletor.
- **A Reserva nunca existe sem a Principal**, em três camadas: (1) o armazenamento
  (`AiSlotsStore`) recusa gravar a Reserva sem Principal e apagar a Principal apaga a Reserva;
  (2) o resolvedor ignora uma Reserva órfã; (3) a tela bloqueia o cartão da Reserva ("Configure a
  Principal primeiro") e pede confirmação ao remover a Principal quando há Reserva.
- **Botão Testar** em cada cartão: usa o que está digitado (mesmo sem salvar) ou, com o slot
  salvo, a configuração guardada. **Só roda quando o usuário toca**; nunca ao abrir a tela,
  digitar ou salvar.

## Por quê

O autor pediu que o usuário pudesse usar a IA que quiser, sem ser obrigado a ter Groq e
Anthropic, com a tela mais curta e uma regra de negócio clara (reserva depende de principal).
E que dê para conferir a chave sem gastar uma importação inteira — mas nunca sozinho, porque
o teste em serviço pago tem custo.

- **`ping()` numa interface própria (`PingableLocator`)**, e não em `LlmTableLocator`: a
  interface principal tem cinco implementações e dublês de teste, e o teste de chave só faz
  sentido para os serviços reais, não para os decoradores de retry/reserva.
- **Regra no armazenamento, não só na tela.** A tela pode ser contornada (dado antigo, backup
  restaurado, bug de UI); o armazenamento e o resolvedor mantêm a regra mesmo assim.
- **Sem retry no teste.** O teste existe para mostrar o erro na hora; repetir esconderia um 429
  e gastaria mais.
- **Sem migração das chaves antigas** (`izifnc.api_key.*`): só o autor usou a versão anterior. Elas
  ficam órfãs no Keystore e são ignoradas.
- **`main` sem tela de chave:** o build padrão usa a API direto, por `--dart-define`, enquanto
  não houver o plano "serviço IziFnc" (1 planilha e 5 relatórios por mês).

## Arquivos tocados

- [`llm_slot.dart`](../lib/features/import/data/llm_slot.dart) — `LlmServiceKind`, `LlmSlot`, `SlotsResolver`.
- [`configured_table_locator.dart`](../lib/features/import/data/configured_table_locator.dart) — cadeia por slots; `envSlotsResolver`.
- [`llm_table_locator.dart`](../lib/features/import/data/llm_table_locator.dart) — `PingableLocator` e as mensagens do teste.
- [`openai_compatible_table_locator.dart`](../lib/features/import/data/openai_compatible_table_locator.dart), [`groq_table_locator.dart`](../lib/features/import/data/groq_table_locator.dart), [`anthropic_table_locator.dart`](../lib/features/import/data/anthropic_table_locator.dart) — `ping()` e modelo escolhido.
- Só na release: `ai_slots_store.dart` (regras e armazenamento seguro), `ai_slots_controller.dart`,
  `ai_settings_screen.dart`, `import_providers.dart`.
- Testes: `configured_table_locator_test`, `ping_test`, `ai_slots_store_test`, `settings_screen_test`.

## Como verificar

1. `flutter analyze`, `flutter test`, `dart run tool/validar.dart`.
2. Na versão dos testadores, no emulador: Configurações › Inteligência artificial → Principal
   (Groq) com a chave → **Testar** ("Funcionou · N s") → Salvar → Reserva libera → Reserva
   (Anthropic) → **Testar** → Salvar. Chave errada mostra "recusou a chave". Remover a Principal
   com Reserva pergunta antes e leva as duas.
3. Importar uma aba: chega ao mapeamento sem aviso de reserva; com a Principal inválida, aparece
   o aviso de que a Reserva respondeu.

## Pendências / próximos passos

- O botão Testar de um serviço pago gasta uma fração de centavo por toque.
- A tela de IA ainda é a mais alta do app (o aviso do topo ocupa boa parte); a 0014 (UX/UI) revê.
- Plano "serviço IziFnc" com limite continua no backlog ("Futuras").
