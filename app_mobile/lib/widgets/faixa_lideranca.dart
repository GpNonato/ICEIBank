import 'package:material_ui/material_ui.dart';

import '../servicos/lideranca.dart';
import '../tema.dart';
import '../util/formatos.dart';

/// Resumo da agência líder, atualizado sozinho a cada consulta periódica.
class FaixaLideranca extends StatelessWidget {
  const FaixaLideranca({super.key, required this.lideranca, this.aoTocar});

  final LiderancaServico lideranca;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lideranca,
      builder: (context, _) {
        final lider = lideranca.lider;
        final semResposta = lideranca.erro != null;
        final atualizado = lideranca.atualizadoEm;
        final troca = lideranca.ultimaTroca;
        return Bloco(
          aoTocar: aoTocar,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              IconeRedondo(
                semResposta ? Icons.cloud_off_rounded : Icons.workspace_premium_rounded,
                cor: semResposta ? Cores.debito : Cores.lider,
                tamanho: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AGÊNCIA LÍDER',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: Cores.textoSecundario),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        lider == null ? 'Sem líder conhecida' : 'Agência $lider',
                        key: ValueKey('$lider-$semResposta'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Cores.texto),
                      ),
                    ),
                    Text(
                      semResposta
                          ? lideranca.erro!
                          : 'via Agência ${lideranca.agenciaConsultada}'
                              '${atualizado != null ? ' · ${hora(atualizado)}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: semResposta ? Cores.debito : Cores.textoSecundario,
                      ),
                    ),
                    if (troca != null)
                      Text(
                        'Troca: Agência ${troca.de} → Agência ${troca.para} às ${hora(troca.em)}',
                        style: const TextStyle(fontSize: 12, color: Cores.alerta, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              if (lideranca.consultando)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.chevron_right_rounded, color: Cores.textoSecundario),
            ],
          ),
        );
      },
    );
  }
}
