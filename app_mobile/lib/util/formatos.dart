import 'dart:math';

String dinheiro(num valor) {
  final negativo = valor < 0;
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '${negativo ? '-' : ''}R\$ $inteiro,${partes[1]}';
}

String _dois(int n) => n.toString().padLeft(2, '0');

String hora(DateTime t) => '${_dois(t.hour)}:${_dois(t.minute)}:${_dois(t.second)}';

/// Aceita "10", "10,5", "10.50" e "1.234,56".
double? lerValor(String texto) {
  var limpo = texto.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (limpo.contains(',')) {
    limpo = limpo.replaceAll('.', '').replaceAll(',', '.');
  }
  final valor = double.tryParse(limpo);
  if (valor == null || valor.isNaN || valor.isInfinite) return null;
  return valor;
}

final _aleatorio = Random.secure();

/// Identificador único da operação, usado pelo backend para não aplicar duas vezes.
String gerarIdOperacao() {
  final sufixo = List.generate(6, (_) => _aleatorio.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return 'app-${DateTime.now().millisecondsSinceEpoch}-$sufixo';
}
