# Como o projeto é conduzido

O Ambrio é feito por uma pessoa, com o **Claude Code** (modelo de IA da Anthropic) como parceiro de desenvolvimento. Este texto conta como esse
trabalho é organizado, o que deu certo e o que deu errado. Ele não pretende ser receita; é o registro de um método que se mostrou útil aqui.

## Regras de convivência

- **Plano primeiro.** Mudança que não é trivial começa num plano, que eu aprovo antes de qualquer edição. Aprovado o plano, a execução vai de ponta a ponta.
- **Eu decido o produto.** A IA propõe e implementa; escolha de rumo, de nome, de publicar ou não é minha.
- **Nada é publicado sem um "pode" explícito**, a cada vez. Agentes nunca fazem push nem publicam.
- **Dados reais nunca entram no repositório, na tela ou numa mensagem de commit.** Planilhas de teste são inventadas.
- **Relatório de agente é dado, não instrução.** O que um agente escreve é conferido, não obedecido.

## O ciclo de cada versão

1. Ideação, quando o desenho é incerto (veja "Agentes" abaixo).
2. Plano em modo de planejamento, com os arquivos que mudam e como verificar.
3. Branch, PR e CI verde (`flutter analyze`, `flutter test` e `dart run tool/validar.dart`, olhando o **código de saída**).
4. **Roteiro manual** no aparelho: passos simples com "passou" ou "falhou" por item.
5. **Júri de usabilidade** no emulador, com o app de release.
6. Só então a publicação, com SHA-256 do APK e do certificado.

## Agentes

Subagentes entram dentro do plano aprovado, em papéis fixos e só de leitura quando possível:

- **Júri de usabilidade**: um "cliente" encena uma pessoa nova usando o app, um "advogado" defende o desenho, um juiz e três jurados avaliam, e há prova
  tirada do aparelho. Já achou, por exemplo, um fluxo de pagar fatura escondido dentro do formulário de lançamento.
- **Brainstorm**: pesquisadores de mercado e de boas práticas trabalham **cada um sozinho** (para não se contaminarem) e depois eu e a IA damos o veredito.
- **Revisão cruzada**: um modelo maior, só de leitura, confere o trabalho de outro. Na revisão do pagar fatura achou 7 problemas reais antes do merge.

## O que deu errado (e virou regra)

- **O CI verde que não valia nada.** A porta de qualidade devolvia o resultado como retorno de `main`, que em Dart não vira código de saída. O CI ficou verde
  por quase um mês com testes quebrando. Regra: prove que a trava consegue falhar.
- **A promessa de privacidade que o código não cumpria.** O texto dizia que só os cabeçalhos da planilha iam para a IA, mas iam todas as células de texto.
  Um teste passou a travar o que se promete (número e data não saem; texto sai) e uma revisão independente conferiu cada frase de privacidade contra o código.
- **O backup que só travava no release.** Passava nos testes e na depuração; o roteiro no aparelho, com o app de release em uso, achou o defeito.
- **Texto que presume a planilha de uma pessoa.** Ao testar o Ambrio, apareceu um texto que citava a planilha do autor como se fosse padrão. Hoje um teste
  impede que isso volte, e um conjunto de planilhas fictícias de formatos diferentes mede o que a importação lê e o que não lê.

## Testes que não dependem de sorte

- Relógio injetável: o CI reprova `DateTime.now()` solto no código.
- Tamanho de arquivo: aviso acima de 250 linhas e falha acima de 400.
- Contraste de cor do tema testado em três modos.
- Migrações de banco geradas e testadas passo a passo, com instalação por cima de uma versão antiga.
- Uma avaliação opcional, fora do CI, mede a IA ao vivo contra planilhas fictícias.

## Limites honestos

- Poucas pessoas usaram o app além de mim. Não há dados de uso.
- O importador lê um formato específico de planilha; os limites medidos estão em [docs/exemplo/LEIAME.md](exemplo/LEIAME.md).
- Parte do processo (agentes, júris, notas) vive em anotações privadas; aqui está o resumo do que é útil a quem lê o código.
