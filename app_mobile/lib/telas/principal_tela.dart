import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../servicos/contas.dart';
import '../servicos/lideranca.dart';
import '../servicos/sessao.dart';
import '../tema.dart';
import 'agencias_tela.dart';
import 'inicio_tela.dart';
import 'perfil_tela.dart';

/// Estrutura com barra de navegação inferior. Mantém a consulta da líder ativa
/// enquanto a pessoa está autenticada e avisa quando a liderança muda.
class PrincipalTela extends StatefulWidget {
  const PrincipalTela({
    super.key,
    required this.config,
    required this.sessao,
    required this.lideranca,
    required this.contas,
  });

  final Configuracao config;
  final Sessao sessao;
  final LiderancaServico lideranca;
  final ContasServico contas;

  @override
  State<PrincipalTela> createState() => _PrincipalTelaState();
}

class _PrincipalTelaState extends State<PrincipalTela> {
  int _aba = 0;
  late int _trocasVistas;

  @override
  void initState() {
    super.initState();
    _trocasVistas = widget.lideranca.trocas.length;
    widget.lideranca.addListener(_avisarTrocaDeLider);
    widget.lideranca.iniciar();
  }

  @override
  void dispose() {
    widget.lideranca.removeListener(_avisarTrocaDeLider);
    widget.lideranca.parar();
    super.dispose();
  }

  void _avisarTrocaDeLider() {
    final trocas = widget.lideranca.trocas;
    while (_trocasVistas < trocas.length) {
      final troca = trocas[_trocasVistas++];
      if (troca.de != null && troca.para != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Cores.primaria,
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Cores.lider),
              const SizedBox(width: 10),
              Expanded(child: Text('Nova líder: Agência ${troca.para} (antes era a Agência ${troca.de}).')),
            ],
          ),
        ));
      }
    }
  }

  void _sair() {
    widget.contas.limpar();
    widget.sessao.sair();
  }

  @override
  Widget build(BuildContext context) {
    final abas = [
      InicioTela(
        sessao: widget.sessao,
        lideranca: widget.lideranca,
        contas: widget.contas,
        aoAbrirAgencias: () => setState(() => _aba = 1),
      ),
      AgenciasTela(lideranca: widget.lideranca),
      PerfilTela(sessao: widget.sessao, config: widget.config, aoSair: _sair),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _aba, children: abas)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (aba) => setState(() => _aba = aba),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Agências'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
