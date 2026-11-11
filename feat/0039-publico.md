# 0039 — O que o público enxerga: segurança, verificação e dependências

**Data:** 2026-10-25 · **Status:** ✅ concluído (aplicado ao público em 2026-11-05)

## O que mudou

- `SECURITY.md`: como relatar uma falha em particular, prazo honesto para um projeto de uma
  pessoa, escopo e riscos aceitos.
- `docs/VERIFICAR.md`: como conferir o APK baixado (SHA-256 do arquivo e certificado de
  assinatura), com os valores da 1.0.1 (o hash bate com o que o GitHub guarda da Release).
- `.github/dependabot.yml`: atualizações semanais de pacotes (pub) e das actions do CI.
- `.mcp.json` sai do git (continua na máquina do autor, agora em `.gitignore`).

## Por quê

A auditoria do que o público vê (2026-10-25) achou: `.mcp.json` público rodando `npx ...@latest`
(pacotes sem versão fixa executados por quem abrir o projeto numa ferramenta que lê o arquivo);
nenhum canal de segurança; relato privado, Dependabot e proteção da `main` desligados; e Release
sem como conferir a autenticidade. Nada de segredo ou dado pessoal foi achado nos arquivos nem no
histórico público (8 commits, e-mail `noreply`), e o APK 1.0.1 não traz chave embutida.

## Arquivos tocados

`SECURITY.md`, `docs/VERIFICAR.md`, `.github/dependabot.yml`, `.gitignore`, `.mcp.json` (removido
do índice).

## Como verificar

- `dart run tool/validar.dart; echo "exit=$?"`.
- Depois da sincronização pública: `gh api repos/IziFnc/IziFnc/private-vulnerability-reporting`
  deve dizer `true`; `git ls-files` do público sem `.mcp.json`; `sha256sum` do APK igual à tabela.

## O que não foi verificado

- Aplicado ao público em 2026-11-05: arquivos sincronizados, relato privado, Dependabot de
  segurança e proteção da `main` (sem force-push nem exclusão) ligados, hashes nas notas da 1.0.1.
- Dependabot de versões só abre PRs no público a partir da próxima semana; ainda não observado.
- O histórico público do `.mcp.json` foi conferido: um commit, sem token nem caminho pessoal.

## Pendências / próximos passos

- Na 1.0.2, acrescentar uma linha à tabela de `docs/VERIFICAR.md` com o hash novo.
