# Como conferir o APK que você baixou

O APK das [Releases](https://github.com/IziFnc/IziFnc/releases) é assinado com a chave do projeto.
Conferir as duas coisas abaixo diz que o arquivo é o que foi publicado e que veio de quem assina o
projeto (Ambrio, antes chamado IziFnc).

## 1. Impressão digital do arquivo (SHA-256)

```bash
sha256sum Ambrio-1.0.4-arm64.apk        # Linux e macOS: shasum -a 256
Get-FileHash Ambrio-1.0.4-arm64.apk     # Windows (PowerShell)
```

O resultado tem de ser igual ao da tabela (e ao das notas da Release).

## 2. Certificado de assinatura

Com o `apksigner` do Android SDK (pasta `build-tools`):

```bash
apksigner verify --print-certs Ambrio-1.0.4-arm64.apk
```

Deve dizer `Verifies` e mostrar o certificado `CN=IziFnc, O=IziFnc, C=BR` (o nome do certificado continua o antigo, de propósito: é a mesma chave de sempre) com o SHA-256 da tabela.
O certificado é o mesmo em todas as versões: se mudar, **não instale** e abra uma issue.

## Valores publicados

| Versão | SHA-256 do APK (`arm64`) |
|---|---|
| 1.0.4 | `1cdc037249a4035d191ad34ee90bc297cf61755113f9af8b983a1d55b1d31909` |
| 1.0.2 | `3853b7aa31bcb1f42bf85b8895c44b31a9adb3de31d7f6b3c00f606b586db1f4` |
| 1.0.1 | `3866365c3191a3a8a4eb97eb13a5855bdd8e09e6d55c3ff639598d7ab484f78f` |

| | SHA-256 do certificado de assinatura |
|---|---|
| Todas as versões | `63eae372c75778c2abddaadf016dbe4bd0845a557a9e7bd202db316497ab4313` |

Cada versão nova acrescenta uma linha à primeira tabela.
