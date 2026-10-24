// Tipos de apoio do pareamento de transferências em [parseSheet].

/// Saída de transferência ainda sem o destino resolvido.
class PendingTransfer {
  PendingTransfer({
    required this.sheetRow,
    required this.valorCents,
    required this.data,
    required this.banco,
    required this.destino,
  });

  final int sheetRow;
  final int valorCents;
  final DateTime data;
  final String banco;
  final String? destino;
}

/// Linha `transfer` de Entrada de Valor: o lado que **recebe**.
class TransferMirror {
  TransferMirror({
    required this.sheetRow,
    required this.valorCents,
    required this.data,
    required this.banco,
    required this.observacao,
  });

  final int sheetRow;
  final int valorCents;
  final DateTime? data;
  final String banco;
  final String? observacao;
  bool used = false;
}
