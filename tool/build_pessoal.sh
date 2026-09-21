#!/usr/bin/env bash
# Gera a versao PESSOAL do IziFnc: o mesmo app, com as chaves de IA de _local/keys/
# ja embutidas (Groq e, se existir, Anthropic), para uso do proprio autor. Instala
# como "IziFnc Pessoal" (id com.getulio.izifnc.pessoal), ao lado da versao normal.
#
#   bash tool/build_pessoal.sh          # celular (arm64), o padrao
#   bash tool/build_pessoal.sh x64      # emulador do Android Studio (x86_64)
#
# ATENCAO: chave embutida num APK pode ser extraida por quem tiver o arquivo. Esta
# versao e SO SUA: o APK sai em _local/build/ (fora do git) e NUNCA vai para uma
# release publica nem se manda para outras pessoas. A versao dos usuarios e a de
# sempre (`flutter build apk --release --target-platform android-arm64`), na qual cada
# pessoa cola a propria chave em Configuracoes > Inteligencia artificial.
set -euo pipefail
cd "$(dirname "$0")/.."

plataforma="${1:-arm64}"
case "$plataforma" in
  arm64) alvo="android-arm64" ;;
  x64) alvo="android-x64" ;;
  *) echo "Plataforma desconhecida: $plataforma (use arm64 ou x64)." >&2; exit 1 ;;
esac

groq_file="_local/keys/groq.txt"
anthropic_file="_local/keys/anthropic.txt"
if [[ ! -s "$groq_file" ]]; then
  echo "Falta $groq_file (so a chave, sem aspas). Nada foi gerado." >&2
  exit 1
fi

defines=("--dart-define=GROQ_API_KEY=$(tr -d '\r\n ' < "$groq_file")")
if [[ -s "$anthropic_file" ]]; then
  defines+=("--dart-define=ANTHROPIC_API_KEY=$(tr -d '\r\n ' < "$anthropic_file")")
  echo "Chaves embutidas: Groq + Anthropic (reserva)."
else
  echo "Chave embutida: Groq (sem $anthropic_file, sem reserva)."
fi

IZIFNC_PESSOAL=1 flutter build apk --release --target-platform "$alvo" "${defines[@]}"

version="$(grep -m1 '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//; s/\+.*//')"
mkdir -p _local/build
out="_local/build/IziFnc-pessoal-${version}-${plataforma}.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$out"
echo
echo "Pronto: $out"
echo "Lembrete: e a versao PESSOAL (com chaves). Nao publique nem compartilhe este arquivo."
