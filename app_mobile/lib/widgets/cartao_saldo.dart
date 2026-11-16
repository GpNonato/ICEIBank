import 'package:material_ui/material_ui.dart';

import '../servicos/contas.dart';
import '../tema.dart';
import '../util/formatos.dart';

/// Saldo da conta selecionada, com opção de ocultar o valor. Quando há operações
/// feitas offline aguardando sincronização, mostra o saldo provisório (UI otimista)
/// e o último saldo confirmado pela agência.
class CartaoSaldo extends StatefulWidget {
  const CartaoSaldo({
    super.key,
    required this.conta,
    required this.saldoProvisorio,
    required this.pendentes,
    required this.aoTrocarConta,
  });

  final Conta conta;
  final double saldoProvisorio;
  final int pendentes;
  final VoidCallback aoTrocarConta;

  @override
  State<CartaoSaldo> createState() => _CartaoSaldoState();
}

class _CartaoSaldoState extends State<CartaoSaldo> {
  bool _oculto = false;

  String _valor(double v) => _oculto ? 'R\$ ••••••' : dinheiro(v);

  @override
  Widget build(BuildContext context) {
    final conta = widget.conta;
    final provisorio = widget.pendentes > 0;
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
          if (provisorio)
            const Text('SALDO PROVISÓRIO',
                style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: Cores.alerta, fontWeight: FontWeight.w700)),
          Row(
            children: [
              Text(
                _valor(provisorio ? widget.saldoProvisorio : conta.saldo),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: provisorio ? Cores.alerta : Cores.texto,
                ),
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
          if (provisorio)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${widget.pendentes} ${widget.pendentes == 1 ? 'operação aguardando' : 'operações aguardando'} '
                'sincronização · confirmado pela agência: ${_valor(conta.saldo)}',
                style: const TextStyle(fontSize: 12, color: Cores.alerta, fontWeight: FontWeight.w600),
              ),
            ),
          Row(
            children: [
              Icon(
                conta.doCache ? Icons.cloud_off_rounded : Icons.schedule_rounded,
                size: 14,
                color: conta.doCache ? Cores.alerta : Cores.textoSecundario,
              ),
              const SizedBox(width: 4),
              Text(
                conta.doCache
                    ? 'Dados salvos às ${hora(conta.atualizadaEm)} (offline)'
                    : 'Atualizado às ${hora(conta.atualizadaEm)}',
                style: TextStyle(fontSize: 12, color: conta.doCache ? Cores.alerta : Cores.textoSecundario),
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
