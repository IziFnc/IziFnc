// Texto de privacidade do IziFnc, em um lugar só.
//
// É a fonte da tela "Privacidade", da folha de consentimento da importação e
// do arquivo PRIVACIDADE.md da raiz (gerado por `dart run tool/gerar_privacidade.dart`;
// um teste confere que o arquivo não ficou para trás). Dart puro, sem Flutter,
// para a ferramenta de linha de comando poder importar.
//
// Rascunho de quem desenvolve, com pesquisa em fontes oficiais (ver o cofre,
// juridico/pesquisa-normativa.md); não é parecer de advogado.

/// Versão do texto. Mudou o sentido de alguma seção? Some 1: o app pede a
/// autorização de novo e mostra o aviso de novo.
const int kPrivacyVersion = 1;

/// Data de vigência desta versão.
const String kPrivacyDate = '25 de outubro de 2026';

/// Onde a pessoa fala com o responsável.
const String kPrivacyContactUrl = 'https://github.com/IziFnc/IziFnc/issues';

/// Uma seção da política: título, parágrafos e, se houver, itens.
class PrivacySection {
  const PrivacySection(this.title, {this.paragraphs = const [], this.bullets = const []});

  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
}

const List<PrivacySection> kPrivacySections = [
  PrivacySection(
    'Em resumo',
    bullets: [
      'O IziFnc não tem conta, login nem servidor. Seus lançamentos, contas e configurações ficam só no seu aparelho.',
      'Quem desenvolve o app não recebe, não vê e não guarda nenhum dado seu.',
      'Há uma única exceção, que você escolhe usar: a importação de planilha com inteligência artificial. Aí o texto da planilha vai ao serviço de IA que você configurou, e o app pede a sua autorização antes.',
    ],
  ),
  PrivacySection(
    'O que fica no seu aparelho',
    bullets: [
      'Um banco de dados local com as suas contas, cartões, lançamentos e configurações.',
      'A chave do serviço de IA, no cofre de chaves do Android (Keystore), criptografada. Ela não entra no backup.',
      'O backup que você mesmo salvar: um arquivo .sqlite sem criptografia. Quem pegar o arquivo lê tudo; guarde em um lugar seguro. Se você o salvar numa pasta de nuvem, ele sai do aparelho.',
    ],
  ),
  PrivacySection(
    'O que sai do aparelho (só na importação com IA)',
    paragraphs: [
      'Quando você importa uma planilha, o app envia ao serviço de IA todo o texto da aba escolhida, inclusive anotações fora das tabelas e o nome da aba (cabeçalhos, nomes dos lançamentos, bancos, observações, e o que mais estiver escrito como texto). É assim que a IA descobre onde ficam as tabelas. O app também envia a sua chave, para o serviço saber quem está pedindo.',
      'Não saem: as células de número e de data, ou seja, os valores e as datas dos lançamentos.',
      'Dois cuidados: um valor que a sua planilha guarda como texto, e não como número, iria junto; e o nome de um lançamento pode revelar algo pessoal (por exemplo, uma farmácia ou uma doação).',
      'O botão Testar, em Configurações, envia só a frase "Responda apenas: ok" e a chave.',
    ],
  ),
  PrivacySection(
    'Para quem o texto vai',
    paragraphs: [
      'Para o serviço que você configurou, e o app fala direto do seu aparelho com ele, sem passar por servidor de quem desenvolve o app. Cada serviço tem a própria política; as informações abaixo foram conferidas em 25 de outubro de 2026 e podem mudar.',
    ],
    bullets: [
      'Groq (Estados Unidos): por padrão não guarda entradas nem respostas; pode registrá-las por até 30 dias para segurança e estabilidade, e a conta pode ativar retenção zero.',
      'Anthropic: apaga entradas e respostas em até 30 dias; casos sinalizados por segurança ou exigência legal podem ficar guardados por mais tempo.',
      'Outro serviço compatível com OpenAI: vale a política dele, que o IziFnc não controla.',
      'Os serviços citados processam dados fora do Brasil.',
    ],
  ),
  PrivacySection(
    'A sua autorização',
    paragraphs: [
      'Antes do primeiro envio, o app mostra uma tela com o que vai, para quem e o que não vai, e só segue se você aceitar. A autorização vale para os serviços que aparecem nessa tela; se você passar a usar um serviço que ainda não autorizou, ela é pedida de novo.',
      'Fica registrada no seu aparelho (e no backup que você salvar), com a data da última autorização e a versão deste texto. Você pode revogar quando quiser, em Configurações > Inteligência artificial ou nesta tela. Sem autorização, a importação não acontece.',
      'Revogar não apaga o que o serviço de IA já recebeu: isso se resolve com ele, conforme a política dele.',
    ],
  ),
  PrivacySection(
    'Os seus direitos',
    paragraphs: [
      'Como os dados estão no seu aparelho, o controle já é seu: você vê, corrige e apaga lançamentos e contas no próprio app, exporta tudo pelo backup e apaga tudo desinstalando o app. Para o que um serviço de IA recebeu, o pedido é feito a esse serviço.',
    ],
  ),
  PrivacySection(
    'Crianças e adolescentes',
    paragraphs: [
      'O IziFnc é um controle financeiro pessoal e não é dirigido a menores de 18 anos.',
    ],
  ),
  PrivacySection(
    'Segurança',
    bullets: [
      'O app só se conecta por https e o Android não faz backup automático dos seus dados.',
      'Chave de IA no Keystore; backup manual sem criptografia (um risco conhecido).',
      'O código é aberto: você pode conferir tudo o que está escrito aqui.',
    ],
  ),
  PrivacySection(
    'Quem é o responsável e como falar',
    paragraphs: [
      'IziFnc é um projeto de código aberto (licença MIT), sem fins lucrativos e sem anúncios. Para dúvidas, pedidos ou problemas de privacidade, abra uma issue em $kPrivacyContactUrl. Para falhas de segurança, use o relato privado de vulnerabilidade do repositório, para não expor o problema em público.',
    ],
  ),
  PrivacySection(
    'Mudanças neste texto',
    paragraphs: [
      'Quando o sentido mudar, a versão sobe, o app mostra o aviso de novo e pede a autorização de novo. O histórico fica no repositório, no arquivo PRIVACIDADE.md.',
    ],
  ),
];

/// O que a folha de consentimento diz sobre cada serviço, em uma linha.
///
/// [key] é a chave do serviço (`groq`, `anthropic` ou `custom:<host>`).
String consentServiceLine(String key) {
  if (key == 'groq') {
    return 'Groq (Estados Unidos): por padrão não guarda; pode registrar por até 30 dias para segurança.';
  }
  if (key == 'anthropic') {
    return 'Anthropic: apaga em até 30 dias; casos sinalizados por segurança ou lei podem ficar mais tempo.';
  }
  final host = key.startsWith('custom:') ? key.substring(7) : key;
  return '$host: vale a política desse serviço, que o IziFnc não controla, e ele pode ficar fora do Brasil.';
}

/// O texto principal da folha de consentimento.
const String kConsentWhatGoes =
    'Para achar onde ficam as tabelas, o IziFnc vai enviar todo o texto da aba, inclusive anotações fora das tabelas e o nome da aba (por exemplo: cabeçalhos, nomes dos lançamentos, bancos e observações), ao serviço de IA abaixo, junto com a sua chave.';

/// O que não vai.
const String kConsentWhatStays =
    'Valores e datas (as células de número e de data) não são enviados e ficam só no seu aparelho.';

/// O PRIVACIDADE.md completo a partir de [kPrivacySections].
String privacyMarkdown() {
  final b = StringBuffer()
    ..writeln('# Política de privacidade do IziFnc')
    ..writeln()
    ..writeln('> Versão $kPrivacyVersion, em vigor desde $kPrivacyDate.')
    ..writeln('> Este arquivo é gerado a partir do texto que o app mostra (`lib/features/settings/domain/privacy_text.dart`,')
    ..writeln('> comando `dart run tool/gerar_privacidade.dart`). É um texto de quem desenvolve o app, escrito com pesquisa em')
    ..writeln('> fontes oficiais, e não um parecer jurídico.')
    ..writeln();
  for (final s in kPrivacySections) {
    b.writeln('## ${s.title}');
    b.writeln();
    for (final p in s.paragraphs) {
      b
        ..writeln(p)
        ..writeln();
    }
    for (final item in s.bullets) {
      b.writeln('- $item');
    }
    if (s.bullets.isNotEmpty) b.writeln();
  }
  return '${b.toString().trimRight().replaceAll('\r\n', '\n')}\n';
}
