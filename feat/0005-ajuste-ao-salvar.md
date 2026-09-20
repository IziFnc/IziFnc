# 0005 — Ajuste de saldo só ao salvar

**Data:** 2026-09-14 · **Status:** ✅ concluído

## O que mudou

Na tela de editar conta, o **"Ajustar saldo" não grava mais nada sozinho**:

- O "Ajustar" do diálogo só **prepara** o ajuste. O card mostra
  `Saldo hoje R$ 490,00 → R$ 600,00 ao salvar`, com um botão para desfazer; o botão de
  ajustar vira "Alterar ajuste", e reabre o diálogo com o valor já preenchido.
- **Salvar** grava a conta e o ajuste **na mesma transação**.
- Sair com ajuste pendente ou campo alterado, pela seta da barra ou pelo voltar do
  Android, pergunta **"Descartar alterações?"**.
- Depois de salvar com ajuste: "Conta salva. Ajuste de + R$ 110,00 registrado."

## Por quê

Apontado pelo autor ao testar no celular: a tela tem um botão Salvar, então quem a usa
espera que nada mude antes dele. Na 0004 o "Ajustar" escrevia no banco na hora e
quebrava essa expectativa, sem nem dar como voltar atrás.

**Mesma transação** porque "ajustei, salvei e o nome não foi (ou foi e o ajuste não)"
seria pior do que o problema original. `AccountsRepository.update` ganhou `adjustTarget`
e chama o `adjustBalance` de sempre, **depois** do recálculo de competência, para o
ajuste usar o fechamento já atualizado.

**Um detalhe que teria virado bug:** ao salvar, a tela libera a saída
(`_leaving = true`) e fecha. Se fechasse no mesmo instante, o `PopScope` ainda veria o
estado antigo e o Salvar abriria o "Descartar?". O fechamento espera o quadro seguinte
(`addPostFrameCallback`).

## Arquivos tocados

- [`account_form_screen.dart`](../lib/features/accounts/presentation/account_form_screen.dart):
  `_pendingAdjust`, detecção de alteração não salva, `PopScope`, card de saldo com a
  previsão
- [`accounts_repository.dart`](../lib/features/accounts/data/accounts_repository.dart):
  `update(..., adjustTarget)` devolve a diferença registrada

Sem mudança de banco.

## Como verificar

```bash
flutter test   # 73 testes
```

- Repositório: o ajuste é gravado junto com a conta; sem ajuste pendente, nada é
  gravado; se o `update` falha, o ajuste também não é gravado.
- Widget: o "Ajustar" não grava; sair sem salvar pergunta e descarta; salvar grava e
  avisa.
- **Emulador:** ajustar para R$ 600,00 e sair pela seta → "Descartar?" → Descartar →
  continua R$ 490,00. Ajustar e salvar → R$ 600,00, com "+ R$ 110,00" no histórico.

## Pendências

Nenhuma. A próxima é a 0006 (cartão vinculado à conta e "Pagar fatura").
