import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../servicos/lideranca.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/indicador_agencias.dart';

/// Aba "Agências": detalhes da eleição de líder (algoritmo de Bully).
class AgenciasTela extends StatelessWidget {
  const AgenciasTela({super.key, required this.lideranca});

  final LiderancaServico lideranca;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lideranca,
      builder: (context, _) {
        final lider = lideranca.lider;
        final semResposta = lideranca.erro != null;
        final trocas = lideranca.trocas.where((t) => t.de != null && t.para != null).toList().reversed;
        return RefreshIndicator(
          onRefresh: lideranca.consultar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Text('Agências', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const Text(
                'A líder é eleita pelo algoritmo de Bully: vence a agência ativa de maior ID.',
                style: TextStyle(color: Cores.textoSecundario),
              ),
              const SizedBox(height: 16),
              Bloco(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    IconeRedondo(
                      semResposta ? Icons.cloud_off_rounded : Icons.workspace_premium_rounded,
                      cor: semResposta ? Cores.debito : Cores.lider,
                      tamanho: 72,
                    ),
                    const SizedBox(height: 12),
                    const Text('LÍDER ATUAL',
                        style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Cores.textoSecundario)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        lider == null ? 'Sem líder conhecida' : 'Agência $lider',
                        key: ValueKey('$lider-$semResposta'),
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      semResposta
                          ? lideranca.erro!
                          : 'Consultada na Agência ${lideranca.agenciaConsultada}'
                              '${lideranca.atualizadoEm != null ? ' às ${hora(lideranca.atualizadoEm!)}' : ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: semResposta ? Cores.debito : Cores.textoSecundario),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consulta automática das 3 agências a cada ${Configuracao.intervaloLideranca.inSeconds} s. '
                      'Se a agência consultada não responder, vale a resposta da próxima.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Cores.textoSecundario),
                    ),
                  ],
                ),
              ),
              TituloSecao('Agências ativas (${lideranca.ativas} de ${Configuracao.numeroAgencias})'),
              ListaAgencias(lideranca: lideranca),
              if (lideranca.divergencia)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Bloco(
                    cor: const Color(0xFFFFF7ED),
                    padding: const EdgeInsets.all(12),
                    child: const Row(
                      children: [
                        Icon(Icons.how_to_vote_rounded, color: Cores.alerta),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'As agências ainda divergem sobre a líder: há uma eleição em andamento.',
                            style: TextStyle(color: Cores.alerta, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const TituloSecao('Trocas percebidas pelo app'),
              Bloco(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: trocas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text('Nenhuma troca de liderança desde que o app abriu.',
                              style: TextStyle(color: Cores.textoSecundario)),
                        ),
                      )
                    : Column(
                        children: [
                          for (final troca in trocas)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const IconeRedondo(Icons.sync_alt_rounded, cor: Cores.alerta),
                              title: Text('Agência ${troca.de} → Agência ${troca.para}'),
                              subtitle: Text('às ${hora(troca.em)}'),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
