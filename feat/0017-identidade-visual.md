# 0017 — Identidade visual: logo A (carteira verde)

**Data:** 2026-09-21 · **Status:** ✅ concluído

## O que mudou

- **Ícone do app** novo: carteira branca com barras e cartões verde/lima sobre degradê verde-floresta.
  Ícone **adaptativo** (Android 8+, com a carteira na zona segura de 66%) e ícone quadrado arredondado
  para o Android antigo.
- **Logo no cabeçalho do menu lateral**, ao lado de "IziFnc — Finanças, sem frescura".
- A **cor do app não mudou** (semente `#00875A`): o verde do logo já combina com ela.
- `flutter_launcher_icons` entra como dependência **só de desenvolvimento** (gera os ícones; não vai no APK).

## Por quê

O autor tinha dois conjuntos de cores e pediu que eu analisasse e desse uma opção; testamos os dois
como fizemos com as IAs (duas branches, cada uma instalada no emulador) e ele escolheu a **A**.

- **A** (carteira, verde-floresta + lima) mantém a semente atual, que dá 4,6:1 de contraste sobre branco;
  o lima é só acento, nunca texto.
- **B** ("Z" esmeralda→ciano sobre marinho) exigia trocar a semente e só passa bem em fundo escuro.
  Ficou arquivada na tag `archive/0017-logo-b` (branch apagada), caso um dia se queira retomar.

## Como os ícones foram feitos

Os originais (`f.png`) ficam em `_local/` (não versionado). O recorte da carteira, sem o texto, foi
composto sobre o degradê do próprio ícone com bordas suavizadas, por um script de System.Drawing
(PowerShell, sem dependência). Os PNGs prontos moram em [`assets/branding/`](../assets/branding/):
`foreground.png` (camada do ícone adaptativo), `icon.png` (legado) e `logo.png` (menu).

O gerador coloca um recuo de 16% no ícone adaptativo; ele foi **removido à mão** em
[`ic_launcher.xml`](../android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml), porque o
`foreground.png` já vem com a carteira na zona segura. **Se regenerar os ícones com
`dart run flutter_launcher_icons`, refaça esse ajuste.**

## Arquivos tocados

- [`assets/branding/`](../assets/branding/) — `icon.png`, `foreground.png`, `logo.png`.
- `android/app/src/main/res/` — mipmaps, `drawable-*/ic_launcher_foreground.png`, `ic_launcher.xml`, `colors.xml`.
- [`app_drawer.dart`](../lib/core/widgets/app_drawer.dart) — logo no cabeçalho.
- `pubspec.yaml` — `flutter_launcher_icons` (dev), configuração e o asset do logo.

## Como verificar

1. `flutter analyze`, `flutter test` (a matriz de telas da 0016 cobre o menu com o logo), `dart run tool/validar.dart`.
2. No aparelho: o ícone do launcher é a carteira verde; abrir o menu mostra o logo ao lado do nome.

## Pendências / próximos passos

- Sem **versão monocromática** para o ícone temático do Android 13+ (o sistema usa uma automática).
- **Tela de abertura** não foi trabalhada (o Android 12+ já usa o ícone).
- A versão `release/teste-usuarios` tem ícone e id próprios (`.teste`) e não recebeu o logo; some quando
  o app virar um só (0019).
