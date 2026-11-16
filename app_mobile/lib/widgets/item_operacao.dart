import 'package:material_ui/material_ui.dart';

import '../servicos/contas.dart';
import '../tema.dart';
import '../util/formatos.dart';

/// Linha de operação (atividade recente e fila de sincronização).
class ItemOperacao extends StatelessWidget {
  const ItemOperacao({super.key, required this.operacao, this.aoReenviar, this.aoDescartar});

  final Operacao operacao;
  final VoidCallback? aoReenviar;
  final VoidCallback? aoDescartar;

  @override
  Widget build(BuildContext context) {
    final op = operacao;
    final (icone, titulo) = switch (op.tipo) {
      TipoOperacao.deposito => (Icons.south_west_rounded, 'Depósito'),
      TipoOperacao.saque => (Icons.north_east_rounded, 'Saque'),
      TipoOperacao.transferencia => (Icons.swap_horiz_rounded, 'Transferência para conta ${op.destino}'),
    };
    final anulada = op.status == 'recusada' || op.status == 'descartada' || op.status == 'conflito';
    final corValor = anulada ? Cores.textoSecundario : (op.credito ? Cores.credito : Cores.debito);
    final corMensagem = switch (op.status) {
      'recusada' || 'conflito' => Cores.debito,
      'pendente' => Cores.alerta,
      _ => Cores.textoSecundario,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconeRedondo(icone, cor: op.credito ? Cores.credito : Cores.debito, tamanho: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Cores.texto)),
                    Row(
                      children: [
                        if (op.offline) ...[
                          const Icon(Icons.cloud_off_rounded, size: 13, color: Cores.textoSecundario),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          'Conta ${op.conta} · ${hora(op.criadaEm)}${op.offline ? ' · feita offline' : ''}',
                          style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
                        ),
                      ],
                    ),
                    if (op.mensagem != null)
                      Text(op.mensagem!, style: TextStyle(fontSize: 12, color: corMensagem)),
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
                      decoration: anulada ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  SeloStatus(status: op.status),
                ],
              ),
            ],
          ),
          if (op.status == 'conflito' && (aoReenviar != null || aoDescartar != null))
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: aoDescartar,
                      style: OutlinedButton.styleFrom(foregroundColor: Cores.textoSecundario),
                      child: const Text('Descartar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: aoReenviar,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                      child: const Text('Reenviar'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SeloStatus extends StatelessWidget {
  const SeloStatus({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (texto, cor, icone) = switch (status) {
      'pendente' => ('Pendente', Cores.alerta, Icons.schedule_rounded),
      'sincronizando' => ('Sincronizando', Cores.destaque, Icons.sync_rounded),
      'sincronizada' => ('Sincronizada', Cores.credito, Icons.cloud_done_rounded),
      'conflito' => ('Conflito', Cores.debito, Icons.error_outline_rounded),
      'recusada' => ('Recusada', Cores.debito, Icons.block_rounded),
      'descartada' => ('Descartada', Cores.textoSecundario, Icons.delete_outline_rounded),
      _ => ('Concluída', Cores.credito, Icons.check_rounded),
    };
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: cor),
          const SizedBox(width: 3),
          Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor)),
        ],
      ),
    );
  }
}
