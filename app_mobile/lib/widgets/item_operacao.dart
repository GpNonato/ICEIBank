import 'package:material_ui/material_ui.dart';

import '../servicos/contas.dart';
import '../tema.dart';
import '../util/formatos.dart';

/// Linha da lista "Atividade recente".
class ItemOperacao extends StatelessWidget {
  const ItemOperacao({super.key, required this.operacao});

  final Operacao operacao;

  @override
  Widget build(BuildContext context) {
    final op = operacao;
    final (icone, titulo) = switch (op.tipo) {
      TipoOperacao.deposito => (Icons.south_west_rounded, 'Depósito'),
      TipoOperacao.saque => (Icons.north_east_rounded, 'Saque'),
      TipoOperacao.transferencia => (Icons.swap_horiz_rounded, 'Transferência para conta ${op.destino}'),
    };
    final recusada = op.status == 'recusada';
    final corValor = recusada ? Cores.textoSecundario : (op.credito ? Cores.credito : Cores.debito);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconeRedondo(icone, cor: op.credito ? Cores.credito : Cores.debito, tamanho: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Cores.texto)),
                Text(
                  'Conta ${op.conta} · ${hora(op.criadaEm)}',
                  style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
                ),
                if (op.mensagem != null)
                  Text(
                    op.mensagem!,
                    style: TextStyle(fontSize: 12, color: recusada ? Cores.debito : Cores.textoSecundario),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${op.credito ? '+' : '-'}${dinheiro(op.valor)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: corValor,
                  decoration: recusada ? TextDecoration.lineThrough : null,
                ),
              ),
              _Selo(status: op.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (texto, cor) = switch (status) {
      'recusada' => ('Recusada', Cores.debito),
      _ => ('Concluída', Cores.credito),
    };
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor)),
    );
  }
}
