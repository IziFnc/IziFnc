/// Letras acentuadas do português e o que viram na busca.
const _folded = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Texto em forma comparável para busca: minúsculo e sem acento, para que
/// "salario" ache "Salário" (no celular quase ninguém digita o acento).
///
/// Cobre as letras acentuadas do português; o resto passa como está.
String searchKey(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_folded[ch] ?? ch);
  }
  return out.toString();
}
