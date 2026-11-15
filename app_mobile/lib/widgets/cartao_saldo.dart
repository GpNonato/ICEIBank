import 'package:material_ui/material_ui.dart';

import '../servicos/contas.dart';
import '../tema.dart';
import '../util/formatos.dart';

/// Saldo da conta selecionada, com opção de ocultar o valor.
class CartaoSaldo extends StatefulWidget {
  const CartaoSaldo({super.key, required this.conta, required this.aoTrocarConta});

  final Conta conta;
  final VoidCallback aoTrocarConta;

  @override
  State<CartaoSaldo> createState() => _CartaoSaldoState();
}

class _CartaoSaldoState extends State<CartaoSaldo> {
  bool _oculto = false;

  @override
  Widget build(BuildContext context) {
    final conta = widget.conta;
    return Bloco(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CONTA ${conta.id} · AGÊNCIA ${conta.agencia}',
                style: const TextStyle(fontSize: 12, letterSpacing: 1.1, color: Cores.textoSecundario),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.aoTrocarConta,
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: const Text('Trocar'),
                style: TextButton.styleFrom(foregroundColor: Cores.destaque, visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          Text(conta.nomeAluno, style: const TextStyle(fontSize: 15, color: Cores.texto)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _oculto ? 'R\$ ••••••' : dinheiro(conta.saldo),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Cores.texto),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _oculto ? 'Mostrar saldo' : 'Ocultar saldo',
                onPressed: () => setState(() => _oculto = !_oculto),
                icon: Icon(
                  _oculto ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Cores.textoSecundario,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: Cores.textoSecundario),
              const SizedBox(width: 4),
              Text(
                'Atualizado às ${hora(conta.atualizadaEm)}',
                style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
              ),
              const Spacer(),
              Text(
                'vetor ${conta.vetor}',
                style: const TextStyle(fontSize: 12, color: Cores.textoSecundario, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}
