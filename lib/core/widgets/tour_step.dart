import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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
}

/// O roteiro fixo do tour, sete paradas: cadastrar a primeira conta, a
/// situação e os filtros da home, a grade de tipos do lançamento (menciona
/// "Pagar fatura" no texto, sem destacar o chip à parte — ver feat 0026),
/// importar planilha, Configurações e o backup dentro dela. Cobre uma função
/// por vez, em vez de esperar a pessoa esbarrar em cada botão sozinha.
const kTourSteps = <TourStep>[
  TourStep(
    anchor: TourAnchor.accountsAdd,
    icon: Icons.account_balance_wallet_outlined,
    title: 'Cadastre suas contas e cartões',
    message:
        'Comece por aqui: cadastre cada conta e cartão que você usa. '
        'Cartões precisam de uma conta dona, que paga a fatura.',
    buttonLabel: 'Cadastrar conta',
    nextRoute: AccountFormScreen.newPath,
    pushNext: true,
  ),
  TourStep(
    anchor: TourAnchor.situationCard,
    icon: Icons.dashboard_outlined,
    title: 'Sua situação de relance',
    message:
        'Quanto há em conta e o que está em aberto nas faturas. Toque no '
        'cartão para ver o detalhe de cada conta e cartão.',
  ),
  TourStep(
    anchor: TourAnchor.homeFilters,
    icon: Icons.filter_alt_outlined,
    title: 'Busque e filtre',
    message:
        'A lupa busca pela descrição; aqui do lado dá para filtrar por tipo, '
        'conta ou cartão, e ordenar por data ou valor.',
    nextRoute: EntryFormScreen.newPath,
    pushNext: true,
  ),
  TourStep(
    anchor: TourAnchor.entryTypeGrid,
    icon: Icons.add_circle_outline,
    title: 'Escolha o tipo',
    message:
        'Despesa, entrada, transferência entre contas ou "Pagar fatura" — '
        'esse último dá pra pagar só uma parte e informar juros, quando a '
        'fatura do banco vier maior. Só liga quando você já tiver um cartão.',
    nextRoute: ImportScreen.path,
  ),
  TourStep(
    anchor: TourAnchor.importPickFile,
    icon: Icons.upload_file_outlined,
    title: 'Importe a planilha que você já usa',
    message:
        'Com as contas cadastradas e a chave de IA configurada, escolha o '
        '.xlsx e importe uma aba (mês) por vez.',
    nextRoute: SettingsScreen.path,
    // Este botão fica mais para baixo na tela (depois do checklist "Antes de
    // começar"): "abaixo" (o padrão) estourava a tela.
    align: ContentAlign.top,
  ),
  TourStep(
    anchor: TourAnchor.settingsMenu,
    icon: Icons.settings_outlined,
    title: 'Configurações',
    message: 'Tema e tamanho do texto, a chave de IA e o backup ficam aqui.',
    nextRoute: DataSettingsScreen.path,
    pushNext: true,
  ),
  TourStep(
    anchor: TourAnchor.backupButton,
    icon: Icons.backup_outlined,
    title: 'Faça backup de vez em quando',
    message:
        'Seus dados ficam só neste aparelho. Salve uma cópia de tempos em '
        'tempos — sem ela, perder o aparelho é perder tudo.',
    buttonLabel: 'Concluir',
    align: ContentAlign.top,
  ),
];
