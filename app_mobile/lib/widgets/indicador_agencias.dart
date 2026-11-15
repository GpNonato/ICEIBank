import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../servicos/lideranca.dart';
import '../tema.dart';

/// Pontos compactos (A0, A1, A2): verde quando a agência responde, vermelho quando não.
class PontosAgencias extends StatelessWidget {
  const PontosAgencias({super.key, required this.lideranca});

  final LiderancaServico lideranca;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < Configuracao.numeroAgencias; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          _Ponto(id: i, estado: lideranca.agencias[i], lider: lideranca.lider == i),
        ],
      ],
    );
  }
}

class _Ponto extends StatelessWidget {
  const _Ponto({required this.id, required this.estado, required this.lider});

  final int id;
  final EstadoAgencia? estado;
  final bool lider;

  @override
  Widget build(BuildContext context) {
    final cor = estado == null ? Cores.textoSecundario : (estado!.online ? Cores.credito : Cores.debito);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: lider ? Border.all(color: Cores.lider, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('A$id', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
        ],
      ),
    );
  }
}

/// Lista detalhada das agências (aba Agências): ativa ou fora do ar, quem cada uma
/// considera a líder e o tempo de resposta.
class ListaAgencias extends StatelessWidget {
  const ListaAgencias({super.key, required this.lideranca});

  final LiderancaServico lideranca;

  @override
  Widget build(BuildContext context) {
    return Bloco(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < Configuracao.numeroAgencias; i++) ...[
            if (i > 0) const Divider(height: 1, color: Cores.borda),
            _LinhaAgencia(id: i, estado: lideranca.agencias[i], ehLider: lideranca.lider == i),
          ],
        ],
      ),
    );
  }
}

class _LinhaAgencia extends StatelessWidget {
  const _LinhaAgencia({required this.id, required this.estado, required this.ehLider});

  final int id;
  final EstadoAgencia? estado;
  final bool ehLider;

  @override
  Widget build(BuildContext context) {
    final online = estado?.online ?? false;
    final verificando = estado == null;
    final cor = verificando ? Cores.textoSecundario : (online ? Cores.credito : Cores.debito);
    final detalhe = verificando
        ? 'verificando...'
        : online
            ? 'considera líder: ${estado!.lider == null ? 'nenhuma' : 'Agência ${estado!.lider}'} · ${estado!.latenciaMs} ms'
            : 'não respondeu à última consulta';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          IconeRedondo(ehLider ? Icons.workspace_premium_rounded : Icons.dns_rounded,
              cor: ehLider ? Cores.lider : cor, tamanho: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agência $id${ehLider ? ' · líder' : ''}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Cores.texto),
                ),
                Text('porta ${Configuracao.portaBase + id} · $detalhe',
                    style: const TextStyle(fontSize: 12, color: Cores.textoSecundario)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(
              verificando ? '...' : (online ? 'Ativa' : 'Fora do ar'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cor),
            ),
          ),
        ],
      ),
    );
  }
}
