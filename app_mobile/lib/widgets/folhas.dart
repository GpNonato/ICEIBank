import 'package:material_ui/material_ui.dart';

import '../tema.dart';
import '../util/formatos.dart';

/// Folha inferior padrão com título, campos e botão de confirmação.
Future<T?> _abrirFolha<T>(
  BuildContext context, {
  required String titulo,
  required String subtitulo,
  required List<Widget> Function(void Function(String?) erro) campos,
  required String acao,
  required T? Function(void Function(String?) erro) confirmar,
}) {
  String? mensagemErro;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void erro(String? texto) => setState(() => mensagemErro = texto);
        void enviar() {
          final resultado = confirmar(erro);
          if (resultado != null) Navigator.pop(context, resultado);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Cores.texto)),
              const SizedBox(height: 4),
              Text(subtitulo, style: const TextStyle(color: Cores.textoSecundario)),
              const SizedBox(height: 18),
              ...campos(erro),
              if (mensagemErro != null) ...[
                const SizedBox(height: 8),
                Text(mensagemErro!, style: const TextStyle(color: Cores.debito)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: enviar, child: Text(acao)),
            ],
          ),
        );
      },
    ),
  );
}

InputDecoration _campo(String rotulo, {String? prefixo}) => InputDecoration(
      labelText: rotulo,
      prefixText: prefixo,
    );

Future<double?> pedirValor(BuildContext context, {required String titulo, required String subtitulo, required String acao}) {
  final valor = TextEditingController();
  return _abrirFolha<double>(
    context,
    titulo: titulo,
    subtitulo: subtitulo,
    acao: acao,
    campos: (_) => [
      TextField(
        controller: valor,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: _campo('Valor (R\$)', prefixo: 'R\$ '),
      ),
    ],
    confirmar: (erro) {
      final quantia = lerValor(valor.text);
      if (quantia == null || quantia <= 0) {
        erro('Informe um valor positivo.');
        return null;
      }
      return quantia;
    },
  );
}

Future<(int, double)?> pedirTransferencia(BuildContext context, int origem) {
  final destino = TextEditingController();
  final valor = TextEditingController();
  return _abrirFolha<(int, double)>(
    context,
    titulo: 'Transferir',
    subtitulo: 'Da conta $origem para outra conta, na mesma agência ou em outra.',
    acao: 'Transferir',
    campos: (_) => [
      TextField(
        controller: destino,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: _campo('Conta de destino'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: valor,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _campo('Valor (R\$)', prefixo: 'R\$ '),
      ),
    ],
    confirmar: (erro) {
      final idDestino = int.tryParse(destino.text.trim());
      final quantia = lerValor(valor.text);
      if (idDestino == null || idDestino < 0) {
        erro('Informe a conta de destino.');
        return null;
      }
      if (idDestino == origem) {
        erro('A conta de destino deve ser diferente da origem.');
        return null;
      }
      if (quantia == null || quantia <= 0) {
        erro('Informe um valor positivo.');
        return null;
      }
      return (idDestino, quantia);
    },
  );
}

Future<int?> pedirConta(BuildContext context) {
  final numero = TextEditingController();
  return _abrirFolha<int>(
    context,
    titulo: 'Acessar conta',
    subtitulo: 'A conta é atendida pela agência número da conta % 3.',
    acao: 'Acessar',
    campos: (_) => [
      TextField(
        controller: numero,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: _campo('Número da conta'),
      ),
    ],
    confirmar: (erro) {
      final id = int.tryParse(numero.text.trim());
      if (id == null || id < 0) {
        erro('Informe o número da conta.');
        return null;
      }
      return id;
    },
  );
}
