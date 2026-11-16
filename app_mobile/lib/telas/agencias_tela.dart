import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../servicos/api.dart';
import '../servicos/lideranca.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/indicador_agencias.dart';

/// Aba "Agências": detalhes da eleição de líder (algoritmo de Bully).
class AgenciasTela extends StatelessWidget {
  const AgenciasTela({super.key, required this.lideranca});

  final LiderancaServico lideranca;

  Future<void> _forcarEleicao(BuildContext context) async {
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      final mensagem = await lideranca.forcarEleicao();
      mensageiro.showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Cores.primaria));
    } on ApiErro catch (erro) {
      mensageiro.showSnackBar(
          SnackBar(content: Text('${erro.mensagem} (HTTP ${erro.status})'), backgroundColor: Cores.debito));
    } on SemConexao catch (erro) {
      mensageiro.showSnackBar(SnackBar(content: Text(erro.toString()), backgroundColor: Cores.debito));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lideranca,
      builder: (context, _) {
        final lider = lideranca.lider;
        final semResposta = lideranca.erro != null;
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: lideranca.erro != null ? null : () => _forcarEleicao(context),
                icon: const Icon(Icons.how_to_vote_rounded),
                label: const Text('Forçar nova eleição'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Cores.texto,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Cores.borda),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              TituloSecao(
                lideranca.historicoDe == null
                    ? 'Histórico de líderes'
                    : 'Histórico de líderes (Agência ${lideranca.historicoDe})',
              ),
              Bloco(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: lideranca.historico.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text('Nenhuma definição de líder registrada ainda.',
                              style: TextStyle(color: Cores.textoSecundario)),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < lideranca.historico.length && i < 8; i++) ...[
                            if (i > 0) const Divider(height: 1, color: Cores.borda),
                            _ItemHistorico(registro: lideranca.historico[i]),
                          ],
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

class _ItemHistorico extends StatelessWidget {
  const _ItemHistorico({required this.registro});

  final RegistroLider registro;

  @override
  Widget build(BuildContext context) {
    final semLider = registro.lider == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          IconeRedondo(
            semLider ? Icons.cloud_off_rounded : Icons.workspace_premium_rounded,
            cor: semLider ? Cores.debito : Cores.lider,
            tamanho: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  semLider ? 'Sem líder' : 'Agência ${registro.lider}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Cores.texto),
                ),
                Text('${registro.motivo} · ${hora(registro.em)}',
                    style: const TextStyle(fontSize: 12, color: Cores.textoSecundario)),
              ],
            ),
          ),
          if (!registro.mudou && !semLider)
            const Text('reeleita', style: TextStyle(fontSize: 12, color: Cores.textoSecundario)),
          if (registro.mudou && !semLider)
            const Text('nova líder',
                style: TextStyle(fontSize: 12, color: Cores.alerta, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
