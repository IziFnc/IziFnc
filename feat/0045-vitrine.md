# 0045 — Vitrine do projeto: README de estudo de caso, capturas e resumo em inglês (1.0.4)

**Data:** 2026-11-17 · **Status:** ✅ concluído (texto pendente da revisão do autor, que o publica em seu nome)

## O que mudou

- **README novo, em formato de estudo de caso**: o que o app faz, instalação com verificação do APK, privacidade, a tabela "por que é assim",
  "como foi construído" (testes, CI, migrações, contraste, júris) e duas histórias (o CI verde que mentia e o backup que só travava no release).
- **`docs/DESENVOLVIMENTO.md`**: o guia técnico que era o README (rodar, testar, gerar o APK, migração, estrutura), agora com o nome Ambrio.
- **`README.en.md`**: resumo em inglês. **`docs/PROCESSO.md`**: como o projeto é conduzido com o Claude Code, dito com honestidade.
- **Capturas** em `docs/telas/claro` e `docs/telas/escuro` (seis telas cada) e `hero.png`, tiradas do **app de verdade num emulador** com um banco
  fictício restaurado por Configurações › Dados. `tool/audit/capturar_vitrine_test.dart` gera esse banco de demonstração.

## Por quê

O projeto passou a ser portfólio (decisão de 2026-11-16). Quem chega ao repositório precisa ver o app, entender as decisões e achar a prova de
qualidade sem ler código. O README antigo era um guia para quem desenvolve.

## Como verificar

Abrir o README no GitHub (as imagens e os links relativos), `dart run tool/validar.dart`, e conferir que nenhuma captura tem dado real (todas vêm do
banco fictício Azul/Verde/Roxo/Âmbar).
