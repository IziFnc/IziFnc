# Política de segurança

O IziFnc é um app Android de finanças pessoais, offline, mantido por uma pessoa só. Esta página diz
como relatar um problema de segurança e o que esperar.

## Versões que recebem correção

Só a **última versão publicada** em [Releases](https://github.com/IziFnc/IziFnc/releases) (hoje a série
1.0.x). Quem usa uma versão mais antiga deve atualizar.

## Como relatar

Use **"Relatar uma vulnerabilidade"** na aba **Security** do repositório
([abrir um relato privado](https://github.com/IziFnc/IziFnc/security/advisories/new)). Assim o
problema não fica exposto em público antes de haver correção.

**Não** abra uma issue pública para falha de segurança e **não** cole dados financeiros reais
(planilhas, backups, chaves de IA) em nenhum relato. Descreva: a versão do app, o que você fez,
o que esperava e o que aconteceu, e o impacto que você vê.

## O que esperar

É um projeto de uma pessoa, sem plantão: resposta inicial em até **7 dias** e correção conforme a
gravidade (falha que expõe dados ou chave de IA tem prioridade sobre o resto). Se você quiser, o
crédito aparece na nota da correção.

## Escopo

**Dentro:** o app Android distribuído nas Releases, o código deste repositório, os workflows de CI
e a assinatura/integridade das Releases (veja [docs/VERIFICAR.md](docs/VERIFICAR.md)).

**Fora:** os serviços de IA de terceiros (reporte a eles); ataques que exigem aparelho desbloqueado
ou com root; e a versão "Pessoal" do autor, que não é distribuída.

## O que o app faz para se proteger

Sem conta e sem servidor; dados só no aparelho; chave de IA no Keystore do Android e fora do backup;
só conexões `https`; backup automático do Android desligado; limite de tamanho e de expansão para
planilhas `.xlsx`; restauração de backup recusa banco adulterado; texto de privacidade e
autorização antes de enviar qualquer coisa à IA ([PRIVACIDADE.md](PRIVACIDADE.md)).

## Riscos conhecidos e aceitos

- O backup que você salva é um arquivo `.sqlite` **sem criptografia**.
- Não há *certificate pinning* nas conexões com os serviços de IA (quebraria a cada troca de
  certificado do serviço).
- O tamanho que um `.zip` declara pode mentir; a defesa é o teto de tamanho do arquivo.
