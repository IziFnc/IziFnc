import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../features/accounts/domain/account_kind.dart';
import '../../features/accounts/presentation/account_form_screen.dart';
import '../../features/entries/presentation/entry_form_screen.dart';
import '../../features/import/presentation/import_screen.dart';
import '../../features/settings/presentation/data_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Cada parada do tour guiado (feat 0026), na ordem em que acontecem. O
/// **índice** de cada valor é o número guardado em `app_settings.tour_step`
/// (ver [TourTarget]) — **não reordenar** a lista de baixo (`kTourSteps`) nem
/// os valores daqui sem pensar em quem já estiver no meio do tour.
enum TourAnchor {
  accountsAdd,
  cardAdd,
  situationCard,
  homeFilters,
  entryTypeGrid,
  importPickFile,
  settingsMenu,
  backupButton,
}

/// Uma parada: o que destacar, o que dizer, e como chegar na próxima.
class TourStep {
  const TourStep({
    required this.anchor,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel = 'Próximo',
    this.nextRoute,
    this.pushNext = false,
    this.extra,
    this.align = ContentAlign.bottom,
  });

  final TourAnchor anchor;
  final IconData icon;
  final String title;
  final String message;

  /// De que lado do alvo mostrar a bolha. A maioria fica perto do topo da
  /// tela (barra, início de uma lista), então "abaixo" (o padrão) costuma
  /// caber melhor; alvos mais para baixo na tela (ex.: depois de um
  /// checklist comprido) precisam de "acima" para não sair da tela.
  final ContentAlign align;

  /// Rótulo do botão da bolha. O padrão serve para a maioria; os extremos
  /// (começar cadastrando, terminar o tour) merecem um verbo mais concreto.
  final String buttonLabel;

  /// Para onde ir ao tocar o botão. `null` = a próxima parada é a mesma tela
  /// (só muda o que está destacado nela).
  final String? nextRoute;

  /// `true` empilha (`context.push`) em vez de trocar de lugar (`context.go`)
  /// — usado quando a próxima parada é uma tela que se volta de verdade (o
  /// formulário de conta, o formulário de lançamento, Dados como sub-tela de
  /// Configurações), não um destino do menu.
  final bool pushNext;

  /// Vai como `extra` na navegação — ex.: pré-selecionar "Cartão" ao abrir o
  /// formulário de conta pro passo [TourAnchor.cardAdd].
  final Object? extra;
}

/// O roteiro fixo do tour, oito paradas: cadastrar a primeira conta, um
/// cartão (se usar), a situação e os filtros da home, a grade de tipos do
/// lançamento (menciona "Pagar fatura" no texto, sem destacar o chip à parte
/// — ver feat 0026), importar planilha, Configurações e o backup dentro
/// dela. Cobre uma função por vez, em vez de esperar a pessoa esbarrar em
/// cada botão sozinha.
const kTourSteps = <TourStep>[
  TourStep(
    anchor: TourAnchor.accountsAdd,
    icon: Icons.account_balance_wallet_outlined,
    title: 'Cadastre sua primeira conta',
    message:
        'Comece por uma conta corrente ou poupança: é nela que ficam seus '
        'lançamentos do dia a dia.',
    buttonLabel: 'Cadastrar conta',
    nextRoute: AccountFormScreen.newPath,
    pushNext: true,
    // O botão fica no meio da tela vazia: "abaixo" (o padrão) empurrava a
    // bolha até estourar a borda de baixo. Achado no celular real, feat 0026.
    align: ContentAlign.top,
  ),
  TourStep(
    // Achado testando com um amigo (feat 0026): o passo de conta sozinho não
    // deixava claro que cartão é outro cadastro à parte — quem criava só a
    // conta ficava sem saber o que fazer a seguir. Este passo aponta pro
    // item "Cadastrar um cartão" que já existe no `FirstStepsCard` da home.
    anchor: TourAnchor.cardAdd,
    icon: Icons.credit_card_outlined,
    title: 'Tem cartão de crédito?',
    message:
        'Cadastre agora: ele fica ligado à conta que você acabou de criar, '
        'que paga a fatura dele. Não usa cartão? Pode voltar sem salvar.',
    buttonLabel: 'Cadastrar cartão',
    nextRoute: AccountFormScreen.newPath,
    pushNext: true,
    extra: AccountKind.creditCard,
  ),
  TourStep(
    anchor: TourAnchor.situationCard,
    icon: Icons.dashboard_outlined,
    title: 'Sua situação num relance',
    message:
        'Mostra quanto você tem nas contas e quanto está em aberto nas '
        'faturas. Toque aqui para ver os valores de cada conta e cartão.',
  ),
  TourStep(
    anchor: TourAnchor.homeFilters,
    icon: Icons.filter_alt_outlined,
    title: 'Busque e filtre',
    message:
        'A lupa procura pela descrição. O filtro, ao lado, separa por tipo, '
        'conta ou cartão e muda a ordem (por data ou valor).',
    nextRoute: EntryFormScreen.newPath,
    pushNext: true,
  ),
  TourStep(
    anchor: TourAnchor.entryTypeGrid,
    icon: Icons.add_circle_outline,
    title: 'Escolha o tipo',
    message:
        'Despesa, entrada, transferência entre contas ou pagamento de '
        'fatura. Em "Pagar fatura" dá para pagar só uma parte ou incluir '
        'juros, quando a fatura vier maior. Essa opção fica disponível '
        'depois que você cadastrar um cartão.',
    nextRoute: ImportScreen.path,
  ),
  TourStep(
    anchor: TourAnchor.importPickFile,
    icon: Icons.upload_file_outlined,
    title: 'Importe a planilha que você já usa',
    message:
        'Com as contas cadastradas e a chave de IA configurada, escolha o '
        'arquivo .xlsx e importe um mês (uma aba) por vez.',
    nextRoute: SettingsScreen.path,
    // Este botão fica mais para baixo na tela (depois do checklist "Antes de
    // começar"): "abaixo" (o padrão) estourava a tela.
    align: ContentAlign.top,
  ),
  TourStep(
    anchor: TourAnchor.settingsMenu,
    icon: Icons.settings_outlined,
    title: 'Configurações',
    message: 'Aqui ficam o tema, o tamanho do texto, a chave de IA e o backup.',
    nextRoute: DataSettingsScreen.path,
    pushNext: true,
  ),
  TourStep(
    anchor: TourAnchor.backupButton,
    icon: Icons.backup_outlined,
    title: 'Faça backup de vez em quando',
    message:
        'Seus dados ficam só neste aparelho. Salve uma cópia de tempos em '
        'tempos: sem ela, se o aparelho for perdido ou trocado, os dados '
        'vão junto.',
    buttonLabel: 'Concluir',
  ),
];
