# 0038 — Privacidade, consentimento e licenças dentro do app

**Data:** 2026-10-25 · **Status:** ✅ concluído (v1.0.2 depende de um "pode" e de um roteiro no aparelho)

## O que mudou

- **Política de privacidade** em PT-BR (`PRIVACIDADE.md`), gerada do mesmo texto que o app
  mostra (`lib/features/settings/domain/privacy_text.dart` → `dart run tool/gerar_privacidade.dart`).
  Um teste confere que o arquivo não ficou para trás.
- **Consentimento específico antes do primeiro envio à IA:** ao tocar em *Escolher arquivo*, uma
  folha "Antes de continuar" diz o que vai (células de texto da aba), para quem (o serviço
  configurado, com a retenção de cada um), o que não vai (valores e datas) e que o serviço fica
  fora do Brasil. Sem aceitar, a importação não começa. A Reserva é outro destinatário: se ela
  existir e não estiver autorizada, a folha pergunta de novo. Texto novo (versão maior) também.
- **Registro e revogação:** data, versão do texto e serviços, só no aparelho (schema v9).
  *Configurações › Inteligência artificial* e a tela de privacidade mostram a autorização e
  deixam revogá-la.
- **Tela de privacidade** (offline) e item "Privacidade" em *Configurações › Geral*.
- **Licenças:** "Licenças e aviso legal" em *Configurações › Geral* lista a licença de cada
  pacote (BSD, MIT e Apache pedem que o aviso acompanhe o app) e traz o aviso de isenção.
- **Aviso na tela inicial** ("Seus dados ficam só neste aparelho") uma vez por versão do texto,
  depois do tour (para não empurrar os alvos das bolhas).
- Migração **v8 → v9**: quatro colunas novas em `app_settings`, com padrão "nunca autorizou".

## Por quê

O app não pedia nenhum consentimento e não tinha política de privacidade, mas manda texto da
planilha a um serviço de terceiros (fora do país) quando a pessoa usa a importação. Pesquisa
normativa no cofre (`juridico/pesquisa-normativa.md`): LGPD art. 8º exige finalidade determinada,
revogação fácil e prova; o autor provavelmente não é agente de tratamento do banco local, mas a
transparência vale de qualquer jeito. Decisões do autor: titular "IziFnc"; contato pelos canais
do GitHub; consentimento dentro do app.

Alternativas descartadas: consentimento genérico na primeira abertura (a lei pede finalidade
determinada, e nada sai do aparelho antes do envio); `url_launcher` para a política (traria
dependência e internet para um texto que cabe no app).

## Arquivos tocados

`privacy_text.dart`, `ai_consent.dart`, `ai_consent_sheet.dart`, `ai_consent_card.dart`,
`privacy_screen.dart`, `privacy_notice.dart`, `privacy_providers.dart`,
`general_settings_screen.dart`, `ai_settings_screen.dart`, `import_screen.dart`,
`settings_table.dart` + `app_database.dart` (v9), `settings_repository.dart`,
`tool/gerar_privacidade.dart`, `PRIVACIDADE.md`, `README.md`.

## Como verificar

- `flutter analyze`, `flutter test` (inclui `test/features/import/ai_consent_test.dart`,
  `test/features/settings/privacy_test.dart`, a matriz de telas com a privacidade e a folha, e o
  teste de migração v9) e `dart run tool/validar.dart`, sempre conferindo o código de saída.
- No aparelho: importar sem autorização → folha → "Agora não" não abre o seletor; "Aceitar"
  abre; trocar a Reserva pede de novo; revogar em Configurações › IA volta a pedir.

## Verificado no emulador (2026-10-25, build debug x64, via adb)

- **Migração v8 → v9 com dados:** instalei o app v8 (`main`), criei a conta Bradesco e o
  lançamento "Mercado R$ 80,50", atualizei por cima com o build desta entrega e li o banco do
  aparelho: `user_version` 9, conta e lançamento intactos, linha de configurações preservada e as
  quatro colunas novas presentes.
- Aviso "Seus dados ficam só neste aparelho" aparece na home (tour já concluído) e leva à tela de
  privacidade, que mostra a versão e o texto.
- **Folha de autorização** (com chave de IA **falsa**, só para abrir o fluxo): aparece ao tocar em
  *Escolher arquivo*; "Agora não" volta sem abrir o seletor e **sem gravar nada**; "Aceitar" grava
  data, versão 1 e `groq` e abre o seletor de arquivos do Android; a segunda vez **não pergunta**;
  "Revogar autorização" em Configurações › Inteligência artificial zera o registro.
- Achado visual (corrigido): os botões da folha ficavam estreitos e à esquerda; agora ocupam a
  largura toda.

## O que não foi verificado

- **Aparelho real:** nada passou por celular de verdade; o emulador é x86_64 e o APK release arm64
  não roda nele. A versão Pessoal (dados reais do autor) ainda não recebeu a migração: **fazer
  backup antes** de instalar a v1.0.2.
- Envio real à IA depois do aceite não foi repetido nesta rodada (as chaves foram testadas
  ontem); o gate fica antes de qualquer envio, e o teste automatizado garante que o seletor/
  localizador não é chamado sem autorização.
- Troca de provedor (Reserva Anthropic) só por teste automatizado, não no aparelho.
- O texto é rascunho de quem desenvolve, com pesquisa em fontes oficiais, **não** parecer de
  advogado; a retenção de cada provedor foi conferida em 2026-10-25 e pode mudar.
- "Provavelmente não há transferência internacional pelo autor" é interpretação (Res.
  CD/ANPD 19/2024, art. 6º); por isso a política **informa** o processamento fora do Brasil.
- O aviso da tela inicial só aparece depois do tour; quem nunca fez o tour vê a política em
  Configurações e na folha de autorização.

## Pendências / próximos passos

- Públicos (cada um com "pode"): `SECURITY.md`, Dependabot, proteção da `main`, tirar o
  `.mcp.json`, hashes na release 1.0.1, e a proposta de `v1.0.2`.
- Brainstorm de marca (decisão do autor) e rascunho do post no LinkedIn.
