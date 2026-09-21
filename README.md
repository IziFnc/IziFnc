# IziFnc

Controle de finanças pessoais — offline, local e sem frescura.

Os dados ficam no aparelho, num SQLite. Sem conta, sem login, sem servidor.

> **Status:** pré-1.0 (a última entrega vem em [`feat/`](feat/README.md)). Funcionando: contas
> e cartões, lançamentos, transferências, pagamento de fatura (com juros opcionais), saldos,
> filtros e busca, importação da planilha `.xlsx` com IA, tema/tamanho do texto/alto contraste
> e **backup e restauração** do banco. O caminho até a 1.0 está no backlog de `feat/`.

## Como usar

**Instalar.** Baixe o `.apk` mais recente em [Releases](https://github.com/IziFnc/IziFnc/releases)
e abra no celular Android. O Android vai pedir para permitir a instalação de "fontes
desconhecidas" (o app não está na Play Store). Atualizações vêm como um APK novo: instale por cima,
os dados ficam.

**Primeiros passos.**

1. **Contas e cartões** (menu ☰): cadastre as suas contas e, para cada cartão, a conta dona, o
   dia do fechamento e se compra **no próprio dia** do fechamento entra na fatura atual ou na
   próxima (confira no app do seu banco).
2. **Ajustar saldo** em cada conta e cartão, para o valor de hoje.
3. Lance despesas e entradas no **+**; use **Pagar fatura** para quitar um cartão (dá para pagar
   parcialmente e informar juros e encargos) e **Transferência** entre contas.
4. Na tela do mês, busque, filtre por tipo e conta e ordene pelo botão de filtros.

**Importar a planilha que você já usa** (`.xlsx`, uma aba por vez, da mais antiga para a mais nova):

1. Crie uma chave grátis em [console.groq.com/keys](https://console.groq.com/keys) e cole em
   **☰ › Configurações › Inteligência artificial › Principal**. (Opcional: uma **Reserva**, chamada só
   se a Principal falhar; e **Testar** confere a chave com uma mensagem mínima, só quando você toca.)
2. **☰ › Importar planilha**, escolha o arquivo e a aba, ligue cada nome da planilha à sua
   conta/cartão e revise a prévia antes de gravar. Reimportar a mesma aba não duplica nada, e dá para
   importar só uma parte.

Sem a sua planilha, teste com as fictícias em [`docs/exemplo/`](docs/exemplo/LEIAME.md). O leitor
procura as tabelas **Despesas Gerais** (`Nome, Valor, Tipo, Banco, Observação, Dia`) e **Entrada de
Valor** (`Nome, Valor, Banco, Observação, Dia`); planilhas com outro layout provavelmente não serão lidas.

**Backup.** Tudo fica só no seu celular. Em **☰ › Configurações › Dados**, **Salvar backup** grava
um arquivo `.sqlite` (uma cópia exata) onde você escolher, e **Restaurar de um arquivo** traz de volta.
Faça de tempos em tempos e guarde fora do aparelho.

**Privacidade.** Sem conta, sem login, sem servidor. O serviço de IA que você configurar recebe
**apenas os textos** da planilha (cabeçalhos e rótulos) para achar onde ficam as tabelas; **valores e
datas dos lançamentos nunca saem do aparelho**. A sua chave fica guardada só no aparelho (Keystore do
Android) e não entra no backup.

**Limites conhecidos.** O plano grátis da Groq limita requisições por minuto (o app repete sozinho
em 429/503). Modelos de IA são aposentados com frequência: se aparecer "model not found", troque o
modelo na tela de IA.

## Stack

| Camada | Escolha |
|---|---|
| Framework | Flutter 3.47 / Dart 3.13 |
| Estado e DI | [Riverpod 3](https://riverpod.dev) com code generation |
| Navegação | [go_router](https://pub.dev/packages/go_router) |
| Banco local | [Drift](https://drift.simonbinder.eu) sobre SQLite |
| Formatação pt-BR | [intl](https://pub.dev/packages/intl) |

Plataforma alvo é **Android**. Não há build web (removido na 0018: o app é offline e local, e
o SQLite em WebAssembly só pesava o repositório).

## Rodando

```bash
flutter pub get
dart run build_runner build          # gera .drift.dart (banco) e .g.dart (providers)
```

O [`build.yaml`](build.yaml) roda o drift num alvo próprio, **antes** do
`riverpod_generator`. Sem isso, os providers que usam classes do banco (`Account`,
`Entry`) falham com `InvalidTypeException`. Por esse motivo o banco usa
`part 'app_database.drift.dart'`, e não `.g.dart`.

**Android:**

```bash
flutter emulators --launch Pixel_9
flutter run
```

**Verificação:**

```bash
flutter analyze
flutter test
dart run tool/validar.dart                    # o que o CI roda
flutter test integration_test -d emulator-5554  # passeio no aparelho (não roda no CI)
```

> Ao mexer em qualquer arquivo com `@riverpod` ou `@DriftDatabase`, rode o
> `build_runner` de novo — ou deixe `dart run build_runner watch` rodando ao lado.

### APK de distribuição (assinado)

```bash
flutter build apk --release --target-platform android-arm64   # ~22 MB, celulares atuais
```

A assinatura vem de `android/key.properties`, que **não é versionado** (nem o keystore em
`_local/keys/`). Sem esse arquivo (CI, outra máquina) o build cai na chave de debug e continua
funcionando, mas esse APK **não serve para distribuir**. Sem o keystore original não dá para
publicar atualizações por cima do que já foi instalado: **guarde uma cópia do
`izifnc-release.jks` e da senha fora deste computador**. Como o keystore é outro, um APK de
release não instala por cima de um build de debug (e vice-versa): desinstale antes.

**Duas versões do app.**

| | Versão do usuário | Versão pessoal |
|---|---|---|
| Como gerar | `flutter build apk --release --target-platform android-arm64` | `bash tool/build_pessoal.sh` |
| Nome / id | IziFnc · `com.getulio.izifnc` | IziFnc Pessoal · `com.getulio.izifnc.pessoal` |
| Chave de IA | cada pessoa cola a sua em Configurações › Inteligência artificial | já embutida (lida de `_local/keys/`) |
| Distribuição | vai para as releases | **nunca**: só para uso do autor |

As duas convivem no mesmo celular (ids diferentes, cada uma com o seu banco). A chave embutida na versão
pessoal pode ser extraída de quem tiver o APK; por isso o arquivo sai em `_local/build/` (fora do git) e
não se publica nem se compartilha. Uma chave configurada dentro do app sempre vale mais que a embutida.

Para desenvolver com a IA sem digitar a chave no app, use
`--dart-define=GROQ_API_KEY="$(cat _local/keys/groq.txt)"`; a chave configurada no app tem prioridade.

### Mudou uma tabela? Migração

O app guarda dados reais no aparelho. Mudança de schema sem migração **apaga ou quebra**
os dados de quem já usa. O fluxo, sempre nesta ordem:

1. **Antes** de mexer: se a versão atual ainda não tem foto em `drift_schemas/`, rode
   `dart run drift_dev make-migrations`.
2. Mude as tabelas e suba o `schemaVersion` em
   [`app_database.dart`](lib/core/database/app_database.dart).
3. `dart run build_runner build` e `dart run drift_dev make-migrations`: isso gera o
   schema novo, o passo em `app_database.steps.dart` e o teste em `test/drift/`.
4. Escreva o passo `fromNToN+1` no `stepByStep` e **preencha o teste de preservação de
   dados** com dados parecidos com os reais.
5. Teste instalando **por cima** de uma versão antiga no emulador, com dados.

Prefira migrações que só **adicionam** (coluna ou tabela). Mudar CHECK ou tipo de coluna
obriga o SQLite a recriar a tabela.

## Estrutura

```
lib/
├── main.dart                  # bootstrap: ProviderScope + locale pt-BR
├── app.dart                   # MaterialApp.router, tema, localização
├── core/                      # o que é compartilhado por todas as features
│   ├── database/              # banco Drift, provider dele e dos repositórios
│   ├── router/                # rotas do go_router
│   ├── theme/                 # ColorScheme claro/escuro
│   └── utils/                 # moeda, datas, YearMonth, campo de valor
└── features/                  # uma pasta por feature, fatiada em camadas
    ├── accounts/              # contas e cartões
    ├── entries/               # lançamentos, regra de mês, tela do mês
    │   ├── data/              #   tabela + repositório
    │   ├── domain/            #   competenceOf, MonthSummary (lógica pura)
    │   └── presentation/      #   telas + providers
    └── settings/              # Geral (tema, virada do mês, sobre) e Dados (backup)

assets/branding/  # logo e ícones do app (origem do ícone adaptativo)
feat/             # histórico de entregas (versionado) — veja abaixo
_local/           # anotações de trabalho (NÃO versionado)
```

Cada feature nasce como `features/<nome>/` com as camadas que precisar
(`data/`, `domain/`, `presentation/`). Pastas de feature não são criadas vazias — elas
aparecem junto com a feature.

### Convenções

- **Dinheiro é `int` em centavos, nunca `double`.** Ponto flutuante acumula erro de
  arredondamento e o saldo deixa de fechar. A conversão para decimal acontece só na
  exibição, em [`core/utils/formatters.dart`](lib/core/utils/formatters.dart).
- **Nada pode assumir que existe internet ou login.** O app é offline-first por decisão,
  não por acaso.
- **O mês de um lançamento vem do dia de corte da conta, não da data.** Lançamento no dia
  do corte ou depois conta para o mês seguinte. Cartão usa o dia de fechamento (e cada
  cartão escolhe se a compra **no próprio dia** do fechamento fica na fatura atual ou vai
  para a próxima); conta corrente usa o dia de virada configurado. A regra toda mora em
  [`competenceForAccount`](lib/features/entries/domain/competence.dart). Não recalcule em outro lugar.
- **Nunca obrigar categoria.** A planilha que o app quer importar não tem categoria, e
  forçar vai contra a ideia de não obrigar o usuário a se reorganizar.
- **Débito é da conta; cartão é sempre crédito e pertence a uma conta**
  (`accounts.linked_account_id`). Compra no débito ou pix é lançada na conta; no crédito,
  no cartão. Não existe "função débito" em cartão.
- **Transferência** (`EntryType.transfer`) é **só conta → conta**. **Pagar fatura**
  (`EntryType.billPayment`) sai de uma conta e vai para um cartão; no formulário, o "Sai
  de" vem com a conta dona do cartão. Nos dois, o mês segue a conta de origem.
- **Saldo não se guarda, se calcula**, em `EntriesRepository.watchBalances`: uma fórmula
  para conta e cartão (no cartão dá negativo, e a tela mostra como "em aberto"). Para
  corrigir, use **Ajustar saldo**, que grava a diferença como lançamento. Nunca edite um
  saldo "na mão".
- **Transferência e ajuste não entram nos totais do mês** (`EntryType.affectsMonthTotals`).
- **Arquivos `.g.dart` e `.drift.dart` são gerados** e estão fora da análise estática.
  Não edite à mão.

## Licença

[MIT](LICENSE): pode usar, copiar, modificar e distribuir, mantendo o aviso de autoria. O app é
oferecido "como está", sem garantia (é um controle financeiro pessoal em pré-lançamento: confira os
valores e faça backup).

## Histórico de features

Toda entrega significativa vira um arquivo em **[`feat/`](feat/README.md)**, explicando
o que mudou, **por que** mudou e como verificar. O `git log` conta o *o quê*; a pasta
`feat/` conta o *porquê* — que é a parte que não dá para reconstruir depois.

Antes de abrir uma nova frente de trabalho, vale ler a entrada mais recente lá.

## Testes visuais com MCP

O [`.mcp.json`](.mcp.json) registra os servidores MCP. O que dirige o app é o
**`mobile-mcp`** (emulador ou aparelho Android via `adb`). O `chrome-devtools` que também
consta ali só servia ao build web, que saiu na 0018; pode ser removido do `.mcp.json`.

Ao mudar o `.mcp.json`, o Claude Code pede para aprovar os servidores de novo e só os
carrega numa sessão nova.

### Android: `mobile-mcp` no Windows

O pacote `mobilecli`, do qual o `mobile-mcp` depende, só instala o binário de Linux. Por
isso o `.mcp.json` pede ao `npx` também o `@mobilenext/mobilecli-windows-amd64`. Se um
dia o projeto for aberto fora do Windows, troque esse pacote pelo da plataforma certa
(`-linux-amd64`, `-darwin-arm64`, …).
