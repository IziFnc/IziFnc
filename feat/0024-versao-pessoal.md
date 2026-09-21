# 0024 — Duas versões do app: a do usuário e a pessoal (com chaves)

**Data:** 2026-09-21 · **Status:** ✅ concluído

## O que mudou

- **Versão do usuário** (a de sempre): sem nenhuma chave; cada pessoa cola a sua em Configurações ›
  Inteligência artificial. É a que vai para as releases públicas.
- **Versão pessoal:** o mesmo app com as chaves de IA (Groq e, se existir, Anthropic) **já embutidas**, gerada por
  `bash tool/build_pessoal.sh`. Instala como **"IziFnc Pessoal"** (`com.getulio.izifnc.pessoal`), **ao lado** da
  normal, cada uma com o seu banco.
- O Gradle liga a variante pela variável de ambiente `IZIFNC_PESSOAL=1` (sufixo do id e nome do app por
  `manifestPlaceholders`); sem ela, tudo continua como era. O rótulo do manifesto passou a vir do placeholder.

## Por quê

O autor quis usar o app no dia a dia sem colar chave, e ao mesmo tempo manter a versão que os outros usam.
A base já servia: `storedSlotsResolver` usa a chave guardada no app e, sem ela, cai no `--dart-define`.

- **Chave embutida é extraível** de quem tiver o APK, então a versão pessoal **nunca** é publicada ou mandada
  a terceiros: o arquivo sai em `_local/build/` (fora do git) e o `.gitignore` do repositório privado de notas
  também ignora `build/` e `*.apk`.
- **Outro id (`.pessoal`)** para coexistir com a normal e para o banco de uma não misturar com o da outra.
- **Verificado no APK:** a normal tem 0 chaves no `libapp.so`; a pessoal tem as chaves embutidas.

## Arquivos tocados

- [`build.gradle.kts`](../android/app/build.gradle.kts), [`AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) — variante pessoal.
- [`tool/build_pessoal.sh`](../tool/build_pessoal.sh) — gera o APK pessoal.
- [`README.md`](../README.md) — tabela das duas versões.

## Como verificar

1. `bash tool/build_pessoal.sh` (precisa de `_local/keys/groq.txt`; usa `anthropic.txt` se existir).
2. `aapt2 dump badging` no APK mostra o pacote `.pessoal` e o nome "IziFnc Pessoal".
3. Instalada, a importação funciona sem configurar chave; a versão normal continua pedindo.

## Pendências / próximos passos

- As chaves de IA têm validade: ao renovar uma, gere a versão pessoal de novo.
- Dados não passam sozinhos de uma versão para a outra: use o backup em Configurações › Dados.
